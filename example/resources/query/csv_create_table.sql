CREATE TABLE IF NOT EXISTS iris (
	sepal_length varchar,
	sepal_width varchar,
	petal_length varchar,
	petal_width varchar,
	species varchar
)
WITH (
    format = 'CSV',
	external_location='s3a://hive/data/csv/',
	skip_header_line_count=1
);
