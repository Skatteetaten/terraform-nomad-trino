# Schema
Schema directory contains examples of different types of serialization.
For local testing check [Makefile](./Makefile)

## AVRO notes
- [Long type problem](https://stackoverflow.com/a/40861211)
- [Union specific](https://stackoverflow.com/a/27499930)
- [How to encode/decode data with avro-tools blogpost](https://www.michael-noll.com/blog/2013/03/17/reading-and-writing-avro-files-from-the-command-line/)

If you want to play with serialization/deserialization of data using cli:
- [avro-tools](http://avro.apache.org/releases.html#Download)

`NB` data in directory `data/` is encoded with schemas together.

## Protobuf notes

- [Official documentation protobuf v3](https://developers.google.com/protocol-buffers/docs/proto3)
- [How to encode/decode data with protoc blogpost](https://medium.com/@at_ishikawa/cli-to-generate-protocol-buffers-c2cfdf633dce)
- [Protoc installation](https://grpc.io/docs/protoc-installation/)

If you want to play with serialization/deserialization of data using cli:
- [protoc](https://github.com/protocolbuffers/protobuf/releases)
