CREATE TABLE IF NOT EXISTS tweets (
	username varchar,
	tweet varchar,
	timestamp bigint
)
WITH (
    format = 'AVRO',
    external_location='s3a://hive/data/avro-tweet/'
);
