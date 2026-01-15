// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_hive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionHiveModelAdapter extends TypeAdapter<TransactionHiveModel> {
  @override
  final int typeId = 0;

  @override
  TransactionHiveModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionHiveModel(
      id: fields[0] as String,
      name: fields[1] as String,
      amountCents: fields[2] as int,
      type: fields[3] as int,
      category: fields[4] as String,
      dateEpochMillis: fields[5] as int,
      note: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionHiveModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amountCents)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.dateEpochMillis)
      ..writeByte(6)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionHiveModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
