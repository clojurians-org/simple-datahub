(require '[clojure.java.jdbc :as j])

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

;; (println (j/query pg-db "select * from information_schema.columns limit 10") ) 
;; (println (j/query ora-db "select * from ALL_TAB_COLUMNS where rownum <= 1 ") ) 

(def ora-columns-query
  " select
      c.OWNER, c.TABLE_NAME, c.COLUMN_NAME, c.DATA_TYPE, m.COMMENTS
    from ALL_TAB_COLUMNS c
      left join ALL_COL_COMMENTS m
        on c.OWNER = m.OWNER
        and c.TABLE_NAME = m.TABLE_NAME
        and c.COLUMN_NAME = m.COLUMN_NAME
    where NOT REGEXP_LIKE(c.OWNER, 'ANONYMOUS|PUBLIC|SYS|SYSTEM|DBSNMP|MDSYS|CTXSYS|XDB|TSMSYS|ORACLE.*|APEX.*|TEST?*|GG_.*|\\$') " )

(def db-query-mapping 
  {"oracle:thin" ora-columns-query
  })
(defn find-db-query [{dbtype :dbtype}]  (db-query-mapping dbtype) )

(comment
  (find-db-query ora-db)

  (sequence 
    (comp (take 1)
          )
    (j/query ora-db (find-db-query ora-db)))
  )

 
