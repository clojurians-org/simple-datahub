(ns gms_mae_conduit)

(import '[java.io PipedInputStream PipedOutputStream])
(import '[org.apache.http.impl.nio.reactor IOReactorConfig])

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
(import '[org.elasticsearch.action.index IndexRequest])
(import '[org.elasticsearch.action.update UpdateRequest])
(import '[java.util.function BiConsumer])

(defn avro->json [rec]
  (let [ schema (.getSchema rec) 
         writer (GenericDatumWriter. schema) 
         in-stream (PipedInputStream.)
         out-stream (PipedOutputStream. in-stream)]
    (future (do (->> out-stream (.jsonEncoder (EncoderFactory/get) schema) (.write writer rec))  
                (.close out-stream)) )
    (slurp in-stream) )
  )

(comment
  (def hosts [(HttpHost. "10.132.37.201" 9092 "http")])
  )
(defn mk-es-bulk-processor [hosts]
  (let [ ; hosts [(HttpHost. "10.132.37.201" 9092 "http")]
         client (-> (RestClient/builder (into-array hosts)) 
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
                      (println :ok [:num (-> response .getItems .length) :ts (.getTookInMillis response)]) )
                    (^void afterBulk [this ^long executionId ^BulkRequest request ^Throwable failure]
                      (println :error [:message failure]) )) ]
    (-> (BulkProcessor/builder (reify BiConsumer (accept [this t u] (.bulkAsync client t u)) ) listener)
        (.setBulkActions 10000)
        (.setFlushInterval (TimeValue/timeValueSeconds 1))
        (.setBackoffPolicy (BackoffPolicy/exponentialBackoff (TimeValue/timeValueSeconds 1) 3)) 
        .build) )
  )

(defn sink-es [es-bulk-processor m]
  (let [ index-req (-> (new IndexRequest ) (.source )) 
         update-req (new UpdateRequest ) ]
    update-req
    #_(.add es-bulk-processor))
  )
(defn process-single-mae [es-bulk-processor v]
  (-> v avro->json println)
  )

(defn -main []
  (println "beginning...")
  (let [ conf { StreamsConfig/BOOTSTRAP_SERVERS_CONFIG "10.132.37.201:9092"
                "schema.registry.url" "http://10.132.37.201:8081"
                StreamsConfig/APPLICATION_ID_CONFIG "gms-mae-job" 
                StreamsConfig/CLIENT_ID_CONFIG "gms-mae-job-client"
                StreamsConfig/DEFAULT_KEY_SERDE_CLASS_CONFIG (-> (Serdes/String) class .getName) 
                StreamsConfig/DEFAULT_VALUE_SERDE_CLASS_CONFIG (.getName GenericAvroSerde) 
                StreamsConfig/COMMIT_INTERVAL_MS_CONFIG 10000
                StreamsConfig/CACHE_MAX_BYTES_BUFFERING_CONFIG 0 }
         es-hosts [ (HttpHost. "10.132.37.201" 9092 "http") ]

         props (doto (new java.util.Properties) (.putAll conf)) 
         mk-kafka-streams (fn [f] (new KafkaStreams (.build (doto (new StreamsBuilder) f)) props))
         es-bulk-processor  (mk-es-bulk-processor es-hosts) ]
    ((comp #(.start %) mk-kafka-streams)
      (fn [stream-builder]
        (-> stream-builder
            (.stream "MetadataAuditEvent")
            (.foreach (reify ForeachAction (apply [this k v] (process-single-mae v)))) ))) )
  (println "finished")
  )

