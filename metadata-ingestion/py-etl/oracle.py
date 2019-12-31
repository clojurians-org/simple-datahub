# -*- coding:utf-8 -*-
#! /usr/bin/python
import sys
import time
import dbms

import sys
defaultencoding = 'utf-8'
if sys.getdefaultencoding() != defaultencoding:
    reload(sys)
    sys.setdefaultencoding(defaultencoding)
#HOST = '10.129.34.171'
#DATABASE = 'fatsym'
#USER = 'SYMETL'
#PASSWORD = 'symetl'
#PORT = '1521'


HOST = '10.129.35.227'
DATABASE = 'EDWDB'
USER = 'comm'
PASSWORD = 'comm'
PORT = '1521'

AVROLOADPATH = '../../metadata-events/mxe-schemas/src/renamed/avro/com/linkedin/mxe/MetadataChangeEvent.avsc'
KAFKATOPIC = 'MetadataChangeEvent'
BOOTSTRAP = '10.132.37.201:9092'
SCHEMAREGISTRY = 'http://10.132.37.201:8081'


def build_rdbms_dataset_mce(dataset_name, schema):
    """
    Create the MetadataChangeEvent
    """

    actor, fields, sys_time = "urn:li:corpuser:datahub", [], long(time.time())

    owner = {"owners":[{"owner":actor,"type":"DATAOWNER"}],"lastModified":{"time":0,"actor":actor}}

    for columnIdx in range(len(schema)):
        fields.append({ "fieldPath":str(schema[columnIdx][0])
                      , "nativeDataType":str(schema[columnIdx][1])
                      , "description":str(schema[columnIdx][2])
                      , "type":{"type":{"com.linkedin.pegasus2avro.schema.StringType":{}}}})

    schema_name = {"schemaName":dataset_name,"platform":"urn:li:dataPlatform:edw_py","version":0,"created":{"time":sys_time,"actor":actor},
               "lastModified":{"time":sys_time,"actor":actor},"hash":"","platformSchema":{"tableSchema":str(schema)},
               "fields":fields}

    mce = {"auditHeader": None,
           "proposedSnapshot":("com.linkedin.pegasus2avro.metadata.snapshot.DatasetSnapshot",
                               {"urn": "urn:li:dataset:(urn:li:dataPlatform:edw_py,"+ dataset_name +",PROD)","aspects": [owner, schema_name]}),
           "proposedDelta": None}

    # Produce the MetadataChangeEvent to Kafka.
    produce_rdbms_dataset_mce(mce)

def produce_rdbms_dataset_mce(mce):
    """
    Produce MetadataChangeEvent records.
    """
    from confluent_kafka import avro
    from confluent_kafka.avro import AvroProducer

    conf = {'bootstrap.servers': BOOTSTRAP,
            'schema.registry.url': SCHEMAREGISTRY}
    record_schema = avro.load(AVROLOADPATH)
    producer = AvroProducer(conf, default_value_schema=record_schema)

    try:
        producer.produce(topic=KAFKATOPIC, value=mce)
        producer.poll(0)
        sys.stdout.write('\n%s has been successfully produced!\n' % mce)
    except ValueError as e:
        sys.stdout.write('Message serialization failed %s' % e)
    producer.flush()

try:
    # Leverage DBMS wrapper to build the connection with the underlying RDBMS,
    # which currently supports IBM DB2, Firebird, MSSQL Server, MySQL, Oracle,
    # PostgreSQL, SQLite and ODBC connections.
    # https://sourceforge.net/projects/pydbms/
    connection = dbms.connect.oracle(USER, PASSWORD, DATABASE, HOST, PORT)

    # Execute platform-specific queries with cursor to retrieve the metadata.
    # Examples can be found in ../mysql-etl/mysql_etl.py
    cursor = connection.cursor()

    ignored_owner_regex = 'ANONYMOUS|PUBLIC|SYS|SYSTEM|DBSNMP|MDSYS|CTXSYS|XDB|TSMSYS|ORACLE.*|APEX.*|TEST?*|GG_.*|\$'

    cursor.execute("""select owner, table_name from ALL_TABLES where NOT REGEXP_LIKE(OWNER, '%s') AND rownum <= 10""" % ignored_owner_regex)
    datasets = cursor.fetchall()


    for dataset in datasets:
      database = dataset[0]
      table = dataset[1]
      
      print ("send meta info: " + table)
      column_info_sql = """
        select
          c.COLUMN_NAME, c.DATA_TYPE, m.COMMENTS
        from ALL_TAB_COLUMNS c
          left join ALL_COL_COMMENTS m
            on c.OWNER = m.OWNER
            and c.TABLE_NAME = m.TABLE_NAME
            and c.COLUMN_NAME = m.COLUMN_NAME
        where c.owner = '%s' and c.table_name = '%s' """ 
  
      cursor.execute(column_info_sql % (database, table))
      schema = cursor.fetchall()
      build_rdbms_dataset_mce(database + "." + table, schema)
    # Build the MetadataChangeEvent via passing arguments.
    

except ValueError as e:
    sys.stdout.write('Error while connecting to RDBMS %s' % e)

sys.exit(0)
