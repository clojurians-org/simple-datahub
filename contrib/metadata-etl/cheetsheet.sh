clj -m dataset_file_connector :file/demo-dat
clj -m dataset_jdbc_connector :jdbc.ora/edw
clj -m gms_mae_conduit

cat metadata_sample/hive_1.sql | bin/lineage_hive_generator.hs
