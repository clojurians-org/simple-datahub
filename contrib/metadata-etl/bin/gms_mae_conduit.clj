#! /usr/bin/env nix-shell                                                         
#! nix-shell ../clj.deps.nix -i "clj -Sdeps '$(cat ../deps.edn)'"                 

(ns gms_mae_conduit)

(require '[clojure.java.io :as io])
(require '[clojure.string :as str])
(require '[cheshire.core :as json])

(import '[java.net URLEncoder])
(import '[java.io ByteArrayOutputStream])
(import '[java.io PipedInputStream PipedOutputStream])
(import '[org.apache.http.impl.nio.reactor IOReactorConfig])
(import '[org.apache.http Header])

(import '[org.apache.avro Schema$Parser])
(import '[org.apache.avro.io DecoderFactory])
(import '[org.apache.avro.generic GenericDatumReader])

(import '[org.apache.avro.io EncoderFactory])
(import '[org.apache.avro.generic GenericDatumWriter])

(import '[org.apache.kafka.common.serialization Serdes])
(import '[io.confluent.kafka.streams.serdes.avro GenericAvroSerde])
(import '[org.apache.kafka.streams StreamsConfig StreamsBuilder KafkaStreams])
(import '[org.apache.kafka.streams.kstream ForeachAction])

(import '[org.apache.http HttpHost])
(import '[org.elasticsearch.common.unit TimeValue])
(import '[org.elasticsearch.client RestClient Client 
           RestClientBuilder$HttpClientConfigCallback
           RestClientBuilder$RequestConfigCallback])
(import '[org.elasticsearch.client RestHighLevelClient])
(import '[org.elasticsearch.action.bulk 
           BulkProcessor BulkProcessor$Listener BackoffPolicy BulkRequest BulkResponse])
(import '[org.elasticsearch.action index.IndexRequest update.UpdateRequest])
(import '[org.elasticsearch.common.xcontent 
            XContentFactory XContentType NamedXContentRegistry DeprecationHandler])

(import '[java.util.function BiConsumer])

(import '[org.neo4j.driver GraphDatabase AuthTokens TransactionWork])

(defn avro->json [rec]
  (let [ schema (.getSchema rec) 
         writer (GenericDatumWriter. schema) 
         out-stream (ByteArrayOutputStream.) 
         json-encoder (.jsonEncoder (EncoderFactory/get) schema out-stream) ]
    (.write writer rec json-encoder)
    (.flush json-encoder)
    (.toString out-stream "UTF-8") )
  )

(defn mk-es-bulk-processor [hosts]
  (let [ client (-> (RestClient/builder (into-array hosts)) 
                    (.setHttpClientConfigCallback
                      (reify RestClientBuilder$HttpClientConfigCallback
                        (customizeHttpClient [this http-client-builder] 
                          (.setDefaultIOReactorConfig http-client-builder
                                (-> (IOReactorConfig/custom) (.setIoThreadCount 1) .build)))) )
                    (.setRequestConfigCallback 
                      (reify RestClientBuilder$RequestConfigCallback 
                        (customizeRequestConfig [this request-config-builder] 
                          (.setConnectionRequestTimeout request-config-builder 0))) )
                    (RestHighLevelClient.) )
         listener (reify BulkProcessor$Listener
                    (beforeBulk [this executionId request])
                    (^void afterBulk [this ^long executionId ^BulkRequest request ^BulkResponse response] 
                      (println :ok [:num (-> response .getItems count) :ts (str (.getTook response)) ]) )
                    (^void afterBulk [this ^long executionId ^BulkRequest request ^Throwable failure]
                      (println :error [:message failure]) )) ]
    (-> (BulkProcessor/builder (reify BiConsumer (accept [this t u] (.bulkAsync client t u (into-array Header []))) ) listener)
        (.setBulkActions 10000)
        (.setFlushInterval (TimeValue/timeValueSeconds 1))
        (.setBackoffPolicy (BackoffPolicy/exponentialBackoff (TimeValue/timeValueSeconds 1) 3)) 
        .build) ))
(defn mk-neo4j-driver [uri username password] (GraphDatabase/driver uri (AuthTokens/basic username password)))

(defn sink-es [es-bulk-processor {urn :urn :as m}]
  (let [ id (-> urn str/lower-case (URLEncoder/encode "UTF-8"))
         cb (-> (XContentFactory/jsonBuilder) .prettyPrint) 
         parser (-> (XContentFactory/xContent XContentType/JSON) 
                    (.createParser NamedXContentRegistry/EMPTY 
                                   DeprecationHandler/THROW_UNSUPPORTED_OPERATION 
                                   (json/generate-string m))) 
         _ (.copyCurrentStructure cb parser) 
         index-req (-> (new IndexRequest "datasetdocument" "doc" id) (.source cb)) 
         update-req (-> (new UpdateRequest "datasetdocument" "doc" id) (.doc cb)
                        (.detectNoop false) (.upsert index-req) (.retryOnConflict (int 3))) ]
    (.add es-bulk-processor update-req))
  )

(defn add-neo4j-entities [driver entitites]
  ; [^statusAspect :removed :uri :name :platform :origin]
  (let [node-type ":`com.linkedin.metadata.entity.DatasetEntity" 
        statement (format "MERGE (node%s {urn: $urn}) ON CREATE SET node%s SET node = $properties RETURN node" 
                          node-type node-type)
        f (fn [tx] (doseq [{urn "urn" :as entity} (clojure.walk/stringify-keys entitites) ] 
                     (.run tx statement {"urn" urn "properties" (mapv entity ["name" "platform" "origin"]) }))) ]
    (with-open [session (.session driver)] (.writeTransaction session (reify TransactionWork (execute [this tx] (f tx))))) )
  )

(comment
  (mk-neo4j-driver "bolt://localhost" "neo4j" "datahub")
  )
(defn parse-urn [urn]
  (let [[_ platform name origin] (re-find #"urn:li:dataset:\(urn:li:dataPlatform:(\S+),(\S+),(\S+)\)" urn) ] 
    { :name name :origin origin :platform platform :urn urn 
      :browsePaths [(->> ["" origin platform (str/replace name "." "/")] (str/join "/") str/lower-case)] }) )

(defmulti mk-es-doc 
  (fn [mae] 
    (let [identity-type (-> (get-in mae ["newSnapshot"]) ffirst) ]
      [identity-type, (-> (get-in mae ["newSnapshot" identity-type "aspects"]) first ffirst) ] )))

(defmulti mk-neo4j-rel
  (fn [mae] 
    (let [identity-type (-> (get-in mae ["newSnapshot"]) ffirst) ]
      [identity-type, (-> (get-in mae ["newSnapshot" identity-type "aspects"]) first ffirst) ] )))

(def user-entity-type ":`com.linkedin.metadata.entity.CorpUserEntity`")
(def dataset-snapshot "com.linkedin.pegasus2avro.metadata.snapshot.DatasetSnapshot")
(def dataset-properties-aspect "com.linkedin.pegasus2avro.dataset.DatasetProperties")
(def dataset-entity-type ":`com.linkedin.metadata.entity.DatasetEntity`")
(def dataset-relationship-OwnedBy  "com.linkedin.metadata.relationship.OwnedBy")
(def dataset-relationship-DownstreamOf  "com.linkedin.metadata.relationship.DownstreamOf")

(defmethod mk-es-doc [ dataset-snapshot dataset-properties-aspect] [mae]
  (let [ { urn "urn" [{{ {description "string"} "description" } dataset-properties-aspect} & _] "aspects" } 
             (get-in mae ["newSnapshot" dataset-snapshot])]
    (merge (parse-urn urn) {:description description  })  ))

(def dataset-lineage-aspect "com.linkedin.pegasus2avro.dataset.UpstreamLineage" )
(defmethod mk-es-doc  [ dataset-snapshot dataset-lineage-aspect]  [mae]
  (let [ { urn "urn" [{{ upstreams "upstreams" } dataset-lineage-aspect} & _] "aspects" } 
             (get-in mae ["newSnapshot" dataset-snapshot])]
    (merge (parse-urn urn) {:upstreams (mapv #(% "dataset") upstreams)})  ))

(defmethod mk-neo4j-rel [ dataset-snapshot dataset-lineage-aspect ] [mae]
  (let [ { urn "urn" [{{ upstreams "upstreams" } dataset-lineage-aspect} & _] "aspects" } 
             (get-in mae ["newSnapshot" dataset-snapshot]) ]
    (concat 
      [ { :statement (format "MATCH (source%s {urn: $urn})-[relation:%s]->() DELETE relation" 
                             dataset-entity-type dataset-relationship-DownstreamOf) 
          :params {"urn" urn}} 
        { :statement (format "MERGE (node%s {urn: $urn}) RETURN node" dataset-entity-type)
          :params {"urn" urn}} ]
      (doseq [{dest-urn "dataset"} upstreams] 
        { :statement (format "MERGE (node%s {urn: $urn}) RETURN node" dataset-entity-type)
          :params {"urn" dest-urn} }
        { :statement (format "MATCH (source%s {urn: $sourceUrn}),(destination%s {urn: $destinationUrn}) MERGE (source)-[r:%s]->(destination) SET r = $properties"
                             dataset-entity-type dataset-entity-type)
          :params {"sourceUrn" urn
                   "destinationUrn" dest-urn
                   "properties" {}}})) ))

; (def dataset-institutional-aspect "com.linkedin.pegasus2avro.common.InstitutionalMemory")
(defn entity-last [str] (last (str/split str #":")))
(def dataset-ownership-aspect "com.linkedin.pegasus2avro.common.Ownership")
(defmethod mk-es-doc [ dataset-snapshot dataset-ownership-aspect ] [mae]
  (let [ { urn "urn" [{{ owners "owners" } dataset-ownership-aspect} & _] "aspects" } 
             (get-in mae ["newSnapshot" dataset-snapshot])]
    (merge (parse-urn urn) {:hasOwners (some? owners) :owners (mapv #(-> "owner" % entity-last) owners)})))
(defmethod mk-neo4j-rel [ dataset-snapshot dataset-ownership-aspect ] [mae]
  (let [ { urn "urn" [{{ upstreams "upstreams" } dataset-lineage-aspect} & _] "aspects" } 
             (get-in mae ["newSnapshot" dataset-snapshot]) ]
    (concat 
      [ { :statement (format "MATCH (source%s {urn: $urn})-[relation:%s]->() DELETE relation" 
                             dataset-entity-type dataset-relationship-OwnedBy) 
          :params {"urn" urn}} 
        { :statement (format "MERGE (node%s {urn: $urn}) RETURN node" dataset-entity-type)
          :params {"urn" urn}} ]
      (doseq [{dest-urn "dataset"} upstreams] 
        { :statement (format "MERGE (node%s {urn: $urn}) RETURN node" user-entity-type)
          :params {"urn" dest-urn} }
        { :statement (format "MATCH (source%s {urn: $sourceUrn}),(destination%s {urn: $destinationUrn}) MERGE (source)-[r:%s]->(destination) SET r = $properties"
                             dataset-entity-type user-entity-type)
          :params {"sourceUrn" urn
                   "destinationUrn" dest-urn
                   "properties" {}}})) ))

(def dataset-status-aspect "com.linkedin.pegasus2avro.common.Status" )
(defmethod mk-es-doc [ dataset-snapshot dataset-status-aspect ] [mae]
  (let [ { urn "urn" [{{ removed "removed" } dataset-status-aspect} & _] "aspects" } 
             (get-in mae ["newSnapshot" dataset-snapshot])]
    (merge (parse-urn urn) {:removed removed}) ))

(def dataset-schema-aspect "com.linkedin.pegasus2avro.schema.SchemaMetadata")
(defmethod mk-es-doc [ dataset-snapshot dataset-schema-aspect ] [mae]
  (let [ { urn "urn" [{{ removed "removed" } dataset-schema-aspect} & _] "aspects" } 
             (get-in mae ["newSnapshot" dataset-snapshot])]
    (merge (parse-urn urn) {:hasSchema true}) )
  )

(defmethod mk-es-doc :default [mae])

(defn process-single-mae [es-bulk-processor v]
  (when-let [doc (-> v avro->json json/parse-string mk-es-doc)]
    (sink-es es-bulk-processor doc)) )
(defn -main []
  (println "beginning...")
  (let [ conf { StreamsConfig/BOOTSTRAP_SERVERS_CONFIG "10.132.37.201:9092"
                "schema.registry.url" "http://10.132.37.201:8081"
                StreamsConfig/APPLICATION_ID_CONFIG "gms-mae-conduit" 
                StreamsConfig/CLIENT_ID_CONFIG "gms-mae-job-client"
                StreamsConfig/DEFAULT_KEY_SERDE_CLASS_CONFIG (-> (Serdes/String) class .getName) 
                StreamsConfig/DEFAULT_VALUE_SERDE_CLASS_CONFIG (.getName GenericAvroSerde) 
                StreamsConfig/COMMIT_INTERVAL_MS_CONFIG 10000
                StreamsConfig/CACHE_MAX_BYTES_BUFFERING_CONFIG 0 }
         es-hosts [ (HttpHost. "10.132.37.201" 9200 "http") ]
         props (doto (new java.util.Properties) (.putAll conf)) 
         mk-kafka-streams (fn [f] (new KafkaStreams (.build (doto (new StreamsBuilder) f)) props))
         es-bulk-processor (mk-es-bulk-processor es-hosts) ]
    ((comp #(.start %) mk-kafka-streams)
      (fn [stream-builder]
        (-> stream-builder
            (.stream "MetadataAuditEvent")
            (.foreach (reify ForeachAction (apply [this k v] (process-single-mae es-bulk-processor v)))) ))) )
  (println "kafka stream started-[running]")
  )
