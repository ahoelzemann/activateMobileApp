class Participant {
  final int id;
  final String studienID;
  final int age;
  final String bangleID;
  final String birthday;
  final String worn_at;

  Participant({this.id, this.studienID, this.age, this.bangleID, this.birthday, this.worn_at});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studienID' : studienID,
      'age': age,
      'bangleID' :bangleID,
      'birthday' : birthday,
      'worn_at' : worn_at
    };
  }

  List<String> toList() {

    return [id.toString(), studienID.toString(), age.toString(), bangleID.toString(), birthday.toString(), worn_at.toString()];

}

  // Implement toString to make it easier to see information about
  // each Participant when using the print statement.
  @override
  String toString() {
    return 'Participant{id: $id, studienID:$studienID, age: $age, bangleID, $bangleID, birthday, $birthday}';
  }
}
