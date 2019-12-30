(require '[clojure.java.io :as io])
(require '[clojure.java.jdbc :as j])
(require '[net.cgrand.xforms :as x])

(import '[org.apache.avro Schema$Parser])
(import '[org.apache.avro.generic GenericRecordBuilder])

(import '[org.apache.kafka.clients.producer KafkaProducer ProducerRecord])
(import '[io.confluent.kafka.serializers KafkaAvroSerializer])

(def pg-db {:dbtype "postgresql"
            :dbname "monitor"
            :host "10.132.37.201"
            :user "monitor"
            :password "monitor" })

(def ora-db {:dbtype "oracle:thin"
             :dbname "EDWDB"
             :host "10.129.35.227"
             :user "comm"
             :password "comm" })

(def ora-columns-query
  " select
      c.OWNER || '.' || c.TABLE_NAME as schema_name
    , t.COMMENTS as schema_description
    , c.COLUMN_NAME as field_path
    , c.DATA_TYPE as native_data_type 
    , m.COMMENTS as description
    from ALL_TAB_COLUMNS c
      left join ALL_TAB_COMMENTS t
        on c.OWNER = t.OWNER
        and c.TABLE_NAME = t.TABLE_NAME
      left join ALL_COL_COMMENTS m
        on c.OWNER = m.OWNER
        and c.TABLE_NAME = m.TABLE_NAME
        and c.COLUMN_NAME = m.COLUMN_NAME
    where NOT REGEXP_LIKE(c.OWNER, 'ANONYMOUS|PUBLIC|SYS|SYSTEM|DBSNMP|MDSYS|CTXSYS|XDB|TSMSYS|ORACLE.*|APEX.*|TEST?*|GG_.*|\\$')
    and c.TABLE_NAME = 'CMS_IND_INFO'
    order by schema_name, c.COLUMN_ID" )

(def db-query-mapping 
  { "oracle:thin" ora-columns-query })
(defn find-db-query [{dbtype :dbtype}]  (db-query-mapping dbtype) )

(defn mk-mce-edn [schema-data]
  (let [ schema-name (-> schema-data first :schema_name) 
         schema-description (-> schema-data first :schema_description) ]
{ "auditHeader" nil
    "proposedSnapshot" 
      ; [ "com.linkedin.pegasus2avro.metadata.snapshot.DatasetSnapshot"
       , { "urn" (format "urn:li:dataset:(urn:li:dataPlatform:edw,%s,PROD)" schema-name) 
         , "aspects" 
             [ ;> DatasetProperties
               { "description" schema-description}
               ;> Ownership
               { "owners" [{"owner" "urn:li:corpuser:datahub", "type" "DEVELOPER"}]
               , "lastModified" {"time" 0, "actor" "urn:li:corpuser:datahub" }}
               ;> SchemaMetadata
             , { "schemaName" schema-name
               , "platform" "urn:li:dataPlatform:edw" 
               , "version" 0
               , "created" {"time" 0, "actor" "urn:li:corpuser:datahub" }
               , "lastModified" {"time" 0, "actor" "urn:li:corpuser:datahub" }
               , "hash" ""
               , "platformSchema" {"documentSchema" ""}
               , "fields" 
                   (doseq [{ fieldPath :field_path 
                             description :description
                             nativeDataType :native_data_type } schema-data]
                     [ { "fieldPath" fieldPath
                       , "description" description
                       , "type" {"type" {"com.linkedin.pegasus2avro.schema.StringType" {}}}
                       , "nativeDataType" nativeDataType} ] )
                 }
             ]}
    ; ]
    "proposedDelta" nil })
  )

(defn edn->avro [schema-file m]
  (let [schema (.parse (new Schema$Parser) (io/file schema-file))
        record-builder (new GenericRecordBuilder schema)]
    (doseq [[k v] m]
        (.set record-builder k  v) )
    (.build record-builder) ) 
  )

(defn -main []
  (let [mce-schema "../../metadata-events/mxe-schemas/src/renamed/avro/com/linkedin/mxe/MetadataChangeEvent.avsc"
        conf { "bootstrap.servers" "10.132.37.201:9092" 
             , "key.serializer" "org.apache.kafka.common.serialization.StringSerializer"
             , "value.serializer" "io.confluent.kafka.serializers.KafkaAvroSerializer" 
             , "schema.registry.url" "http://10.132.37.201:8081"}
        prop (doto (new java.util.Properties) (.putAll conf)) 
        kp (new KafkaProducer prop)] 
    (sequence 
      (comp
          (partition-by :schema_name)
          (map mk-mce-edn)
          (map (partial edn->avro mce-schema) )
          (map #(.send kp (new ProducerRecord "MetadataChangeEvent" %) ))
          )
      (j/query ora-db (find-db-query ora-db)) ) 
    (println "finished") )
  )

(comment
  )
