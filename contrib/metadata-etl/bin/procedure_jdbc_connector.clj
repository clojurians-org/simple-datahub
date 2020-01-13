(ns procedure_oracle_connector)

(require '[clojure.java.jdbc :as j])

(defn test-conf []
    { :in { :db { :dbtype "oracle:thin" :dbname "EDWDB" :host "10.129.35.227" :user "comm" :password "comm" } }
      :params {:origin "PROD" }
      :out { :kafka { "bootstrap.servers" "10.132.37.201:9092"
                    , "schema.registry.url" "http://10.132.37.201:8081" }} } )

(def oracle-procedure-query
  " select u.OWNER || '.' || u.object_name as prc_name, dbms_metadata.get_ddl('PROCEDURE', u.object_name, u.OWNER) as text
    from ALL_OBJECTS u
    where u.OBJECT_TYPE in ('PROCEDURE')
    and u.object_name NOT IN ('PR_TP_WLD_WRITEOFF5')
  ")

(comment
  (def data (j/query (get-in (test-conf) [:in :db]) oracle-procedure-query
                     {:row-fn (fn [row] [(:prc_name row)  (-> row :text .stringValue ) ] ) }) ) 

  (count data) 
   ((comp doall sequence)  
      (comp (map (fn [[prc_name text]] (spit (str "metadata_local/procedure/oracle/" prc_name ".prc") text))) ) 
      data)
  )

