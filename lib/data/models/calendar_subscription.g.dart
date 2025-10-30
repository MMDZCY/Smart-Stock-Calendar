// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_subscription.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarSubscriptionAdapter extends TypeAdapter<CalendarSubscription> {
  @override
  final int typeId = 1;

  @override
  CalendarSubscription read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarSubscription(
      id: fields[0] as String,
      name: fields[1] as String,
      url: fields[2] as String,
      lastSync: fields[3] as DateTime,
      isEnabled: fields[4] as bool,
      syncIntervalHours: fields[5] as int,
      color: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CalendarSubscription obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.lastSync)
      ..writeByte(4)
      ..write(obj.isEnabled)
      ..writeByte(5)
      ..write(obj.syncIntervalHours)
      ..writeByte(6)
      ..write(obj.color);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarSubscriptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
