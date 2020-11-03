CREATE OR REPLACE VIEW hive.default.flattenedjson AS
  SELECT a.description,
         a.foo.bar,
         a.foo.quux,
         a.foo.level1.l2string,
         a.foo.level1.l2struct.level3,
         a.wibble,
         b.entry,
         b.entrydetails
  FROM   (SELECT * FROM hive.default.somejson) a
    CROSS JOIN UNNEST (wobble) b
  (
         entry,
         entrydetails
  );
