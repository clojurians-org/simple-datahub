(ns gms_dependency_sandbox)

(require '[clojure.java.io :as io])
(import '[org.apache.zookeeper.server.quorum QuorumPeerMain])
(import '[kafka Kafka])
(import '[io.confluent.kafka.schemaregistry.rest SchemaRegistryMain])
(import '[com.opentable.db.postgres.embedded EmbeddedPostgres])
(import '[org.elasticsearch.bootstrap Elasticsearch])
(import '[org.neo4j.server CommunityEntryPoint])
(import '[pl.allegro.tech.embeddedelasticsearch EmbeddedElastic])


(defn- string-array [v] (into-array String v))
(defn stop-service [service-future] (future-cancel service-future) )

(defn start-zk [config-file]
  (try (QuorumPeerMain/main (string-array [config-file])) (catch Exception e (str "EX: " (.getMessage e)) )) )

(defn start-kafka [config-file]
  (try (Kafka/main (string-array [config-file])) (catch Exception e (str "EX: " (.getMessage e)) )) )

(defn start-kafka-schema [config-file]
  (try (SchemaRegistryMain/main (string-array [config-file])) (catch Exception e (str "EX: " (.getMessage e)) )) )

(defn start-pg [config-file]
  (try (-> (EmbeddedPostgres/builder) (.setPort 5432) .start) (catch Exception e (str "EX: " (.getMessage e)) )) )

(defn start-es [config-file]
  (try (-> (EmbeddedElastic/builder) (.withElasticVersion "6.8.6") .build .start)
       (catch Exception e (str "EX: " (.getMessage e)) )) )

(defn start-neo4j [config-file]
  (try (CommunityEntryPoint/main (string-array ["--home-dir" "run/neo4j"])) (catch Exception e (str "EX: " (.getMessage e)) ))  )

(defn -main []
  (let [ zk-service (future (start-zk (-> "sandbox/zoo_sample.cfg" io/resource io/file str)) ) 
         kafka-service (future (start-kafka (-> "sandbox/server.properties" io/resource io/file str)))
         kafka-schema-service (future (start-kafka-schema (-> "sandbox/schema-registry.properties" io/resource io/file str)))
         pg-service (start-pg nil)
         es-service (start-es nil)
         neo4j-service (start-neo4j nil)
        ]
    [@zk-service @kafka-service @kafka-schema-service @pg-service @es-service @neo4j-service]
    ) 
  )
