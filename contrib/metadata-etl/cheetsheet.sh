clj -m dataset_file_connector :file/demo-dat
clj -m dataset_jdbc_connector :jdbc.ora/edw
clj -m gms_mae_conduit

ls metadata_sample/hive_*.sql | bin/lineage_hive_generator.hs
