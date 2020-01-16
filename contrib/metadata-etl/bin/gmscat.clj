#! /usr/bin/env nix-shell
#! nix-shell ../clj.deps.nix -i "clj -Sdeps '$(cat ../deps.edn)'"

(ns gmscat)

(require '[clojure.edn :as edn])
(require '[clojure.pprint :as pprint])
(require '[clojure.java.io :as io])
(require '[clojure.java.jdbc :as j])
(require '[cheshire.core :as json])
(require '[net.cgrand.xforms :as x])


(import '[org.apache.avro Schema$Parser])
(import '[org.apache.avro.io DecoderFactory])
(import '[org.apache.avro.generic GenericDatumReader])

(import '[org.apache.kafka.clients.producer KafkaProducer ProducerRecord])
(import '[io.confluent.kafka.serializers KafkaAvroSerializer])

(defn json->avro [schema-file m]
  (let [schema (.parse (new Schema$Parser) (io/file schema-file))
        reader (new GenericDatumReader schema)]
    (->> m (.jsonDecoder (DecoderFactory/get) schema) (.read reader nil))) )

(defn load-selector-conf [args]
  (when (not= (count args) 1) 
    (println "** the selector paramter is missing!")
    (System/exit 1) )
  (let [selector (edn/read-string (first *command-line-args*))
        conf (-> "./gms.conf.edn" io/resource slurp edn/read-string selector)] 
    (when (nil? conf) 
      (println "** the selector conf is missing!")
      (System/exit 1)) 
    (pprint/pprint conf)
    conf ))

(defn test-conf []
    { :connect { :kafka { "bootstrap.servers" "10.132.37.201:9092"
                        , "schema.registry.url" "http://10.132.37.201:8081" }} })

(def mce-schema "../../metadata-events/mxe-schemas/src/renamed/avro/com/linkedin/mxe/MetadataChangeEvent.avsc")
(defn -main [& args]
  (println "starting...")
  (let [ conf (load-selector-conf args) 
       ; conf (test-conf)
       kafka-conf (merge (get-in conf [:connect :kafka]) 
                         { "key.serializer" "org.apache.kafka.common.serialization.StringSerializer"
                         , "value.serializer" "io.confluent.kafka.serializers.KafkaAvroSerializer" }) 
       _ (println "** kafka-conf" kafka-conf)
       prop (doto (new java.util.Properties) (.putAll kafka-conf)) 
       kp (new KafkaProducer prop)
       kafka-send (fn [rec] (-> kp (.send (new ProducerRecord "MetadataChangeEvent" rec) ) ) )]
    ((comp doall sequence) 
      (comp
          (map (partial json->avro mce-schema) )
          (map kafka-send)
          x/count
          (map (partial println "total table num: "))
          )
     (-> *in* io/reader line-seq))
    (.flush kp) )
  (println "finished") 
  )
