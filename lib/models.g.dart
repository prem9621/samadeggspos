// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyRateAdapter extends TypeAdapter<DailyRate> {
  @override
  final int typeId = 0;

  @override
  DailyRate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyRate(
      date: fields[0] as String,
      baseRate: fields[1] as double,
    );
  }

  @override
  void write(BinaryWriter writer, DailyRate obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.baseRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PartyAdapter extends TypeAdapter<Party> {
  @override
  final int typeId = 1;

  @override
  Party read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Party(
      name: fields[0] as String,
      phone: fields[1] as String?,
      address: fields[2] as String?,
      adjustmentType: fields[3] as String,
      adjustmentValue: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Party obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.phone)
      ..writeByte(2)
      ..write(obj.address)
      ..writeByte(3)
      ..write(obj.adjustmentType)
      ..writeByte(4)
      ..write(obj.adjustmentValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SaleAdapter extends TypeAdapter<Sale> {
  @override
  final int typeId = 2;

  @override
  Sale read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sale(
      partyKey: fields[0] as int,
      saleDate: fields[1] as String,
      eggQuantity: fields[2] as double,
      baseRate: fields[3] as double,
      adjustedRate: fields[4] as double,
      amount: fields[5] as double,
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Sale obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.partyKey)
      ..writeByte(1)
      ..write(obj.saleDate)
      ..writeByte(2)
      ..write(obj.eggQuantity)
      ..writeByte(3)
      ..write(obj.baseRate)
      ..writeByte(4)
      ..write(obj.adjustedRate)
      ..writeByte(5)
      ..write(obj.amount)
      ..writeByte(6)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
