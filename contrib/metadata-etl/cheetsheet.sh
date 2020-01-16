# 1. kafka-streams or flik gms job
clj -m gms_mae_conduit
# bin/gms_kafka.clj
# bin/gms_flink.clj

# 2. load interface file
cat metadata_sample/demo.dat | bin/gmscat.clj

# 3. load jdbc dataset schema
bin/dataset_jdbc_generator.clj :jdbc.ora/edw | bin/gmscat.clj

# 4. load hive lineage by paring sql files
ls metadata_sample/hive_*.sql | bin/lineage_hive_generator.hs
# ls metadata_sample/hive_*.sql | bin/lineage_hive_generator.hs | bin/gmscat.clj
