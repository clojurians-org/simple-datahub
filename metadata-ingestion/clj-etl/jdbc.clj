(require '[clojure.java.io :as io])
(require '[clojure.java.jdbc :as j])
(require '[cheshire.core :as json])
(require '[net.cgrand.xforms :as x])

(import '[org.apache.avro Schema$Parser])
(import '[org.apache.avro.io DecoderFactory])
(import '[org.apache.avro.generic GenericDatumReader])

(import '[org.apache.kafka.clients.producer KafkaProducer ProducerRecord])
(import '[io.confluent.kafka.serializers KafkaAvroSerializer])

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
    and c.OWNER='ODS' AND c.TABLE_NAME = 'BHS_BA_CUST_CSN_BOOK'
    order by schema_name, c.COLUMN_ID" )

(def db-query-mapping 
  { "oracle:thin" ora-columns-query })
(defn find-db-query [{dbtype :dbtype}]  (db-query-mapping dbtype) )

(defn mk-mce-json [schema-data]
  (let [ schema-name (-> schema-data first :schema_name) 
         schema-description (-> schema-data first :schema_description) ]
    (json/generate-string 
      { "auditHeader" nil
        "proposedSnapshot" 
          { "com.linkedin.pegasus2avro.metadata.snapshot.DatasetSnapshot"
           , { "urn" (format "urn:li:dataset:(urn:li:dataPlatform:edw,%s,PROD)" schema-name) 
             , "aspects"
                 [ { "com.linkedin.pegasus2avro.dataset.DatasetProperties" 
                     { "description" {"string" schema-name}
                       "uri" nil
                       "tags" []
                       "customProperties" {}
                      }}
                 , { "com.linkedin.pegasus2avro.common.Status" {"removed" false}}
                 , { "com.linkedin.pegasus2avro.common.Ownership"
                     { "owners" [{"owner" "urn:li:corpuser:datahub", "type" "DEVELOPER", "source" nil}]
                     , "lastModified" {"time" 0, "actor" "urn:li:corpuser:datahub", "impersonator" nil}}} 
                 , { "com.linkedin.pegasus2avro.schema.SchemaMetadata"
                     { "schemaName" schema-name
                     , "platform" "urn:li:dataPlatform:edw" 
                     , "version" 0
                     , "created" {"time" 0, "actor" "urn:li:corpuser:datahub", "impersonator" nil}
                     , "lastModified" {"time" 0, "actor" "urn:li:corpuser:datahub", "impersonator" nil}
                     , "deleted" nil
                     , "dataset" nil
                     , "cluster" nil
                     , "hash" ""
                     , "platformSchema" {"com.linkedin.pegasus2avro.schema.EspressoSchema" 
                                          {"documentSchema" "", "tableSchema" ""} }
                     , "fields"
                         (for [{ fieldPath :field_path 
                                   description :description
                                   nativeDataType :native_data_type } schema-data]
                           { "fieldPath" fieldPath
                             , "jsonPath" nil
                             , "nullable" false
                             , "description" (when (some? description) {"string" description} ) 
                             , "type" {"type" {"com.linkedin.pegasus2avro.schema.StringType" {}}}
                             , "nativeDataType" nativeDataType
                             , "recursive" false} )
                     , "primaryKeys" nil
                     , "foreignKeysSpecs" nil
                       }} 
                 ]} }
        "proposedDelta" nil }) ))

(defn json->avro [schema-file m]
  (let [schema (.parse (new Schema$Parser) (io/file schema-file))
        reader (new GenericDatumReader schema)
        ]
    (->> m (.jsonDecoder (DecoderFactory/get) schema) (.read reader nil))) 
  )

(def mce-schema "../../metadata-events/mxe-schemas/src/renamed/avro/com/linkedin/mxe/MetadataChangeEvent.avsc")

(let [ db {:dbtype "oracle:thin" :dbname "EDWDB" :host "10.129.35.227" :user "comm" :password "comm" }
         ; db {:dbtype "postgresql" :dbname "monitor" :host "10.132.37.201" :user "monitor" :password "monitor" } 
         ; db {:dbtype "mysql" :dbname "bus" :host "10.132.37.200" :user "api" :password "api" } 
         conf { "bootstrap.servers" "10.132.37.201:9092" 
              , "key.serializer" "org.apache.kafka.common.serialization.StringSerializer"
              , "value.serializer" "io.confluent.kafka.serializers.KafkaAvroSerializer" 
              , "schema.registry.url" "http://10.132.37.201:8081"
              , "group.id" "MetadataChangeEvent"
              }
         prop (doto (new java.util.Properties) (.putAll conf)) 
         kp (new KafkaProducer prop)
         kafka-send (fn [rec] (.send kp (new ProducerRecord "MetadataChangeEvent" rec) ))]
    ((comp doall sequence) 
      (comp
          (partition-by :schema_name)
          (map mk-mce-json)
          (map (partial json->avro mce-schema) )
          (take 10)
          #_(map kafka-send)
          x/count
          (map (partial println "total record num: "))
          )
      (j/query db (find-db-query db)) ) )

(println "finished") 
