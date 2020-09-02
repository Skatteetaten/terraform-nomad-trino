CREATE TABLE IF NOT EXISTS somejson (
  description varchar,
  foo ROW (
    bar varchar,
	quux varchar,
	level1 ROW (
	  l2string varchar,
	  l2struct ROW (
	    level3 varchar
	  )
	)
  ),
  wibble varchar,
  wobble ARRAY (
    ROW (
      entry int,
	  EntryDetails ROW (
	    details varchar,
		details2 int
	  )
	)
  )
)
WITH (
  format = 'JSON',
  external_location = 's3a://hive/data/json/'
);
