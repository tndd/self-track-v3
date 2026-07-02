// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'records_dao.dart';

// ignore_for_file: type=lint
mixin _$RecordsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecordsTable get records => attachedDatabase.records;
  $TagsTable get tags => attachedDatabase.tags;
  $RecordTagsTable get recordTags => attachedDatabase.recordTags;
  RecordsDaoManager get managers => RecordsDaoManager(this);
}

class RecordsDaoManager {
  final _$RecordsDaoMixin _db;
  RecordsDaoManager(this._db);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db.attachedDatabase, _db.records);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$RecordTagsTableTableManager get recordTags =>
      $$RecordTagsTableTableManager(_db.attachedDatabase, _db.recordTags);
}
