(import '[org.apache.kafka.streams StreamsConfig])
(import '[org.apache.kafka.common.serialization Serdes])
(import '[io.confluent.kafka.streams.serdes.avro GenericAvroSerde])

(defn -main []
(let [conf { StreamsConfig/BOOTSTRAP_SERVERS_CONFIG "10.132.37.201:9092"
             "schema.registry.url" "http://10.132.37.201:8081"
             StreamsConfig/APPLICATION_ID_CONFIG "mce-kafka-job" 
             StreamsConfig/CLIENT_ID_CONFIG "mce-kafka-job-client"
             StreamsConfig/DEFAULT_KEY_SERDE_CLASS_CONFIG (-> (Serdes/String) class .getName) 
             StreamsConfig/DEFAULT_VALUE_SERDE_CLASS_CONFIG (.getName GenericAvroSerde) 
             StreamsConfig/COMMIT_INTERVAL_MS_CONFIG 10000
             StreamsConfig/CACHE_MAX_BYTES_BUFFERING_CONFIG 0
             }]
  
  ))


