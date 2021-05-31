class Participant {
  final int id;
  final String studienID;
  final int age;
  final String bangleID;
  final String birthday;
  final String worn_at;
  final bool bctGroup;
  final String gender;

  Participant(
      {this.id,
        this.studienID,
        this.age,
        this.bangleID,
        this.birthday,
        this.worn_at,
        this.bctGroup,
        this.gender});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'studienID': studienID,
      'age': age,
      'bangleID': bangleID,
      'birthday': birthday,
      'worn_at': worn_at,
      'bctGroup': bctGroup,
      'gender': gender
    };
  }

  List<String> toList() {
    return [
      id.toString(),
      studienID.toString(),
      age.toString(),
      bangleID.toString(),
      birthday.toString(),
      worn_at.toString(),
      bctGroup.toString(),
      gender.toString()
    ];
  }

  // Implement toString to make it easier to see information about
  // each Participant when using the print statement.
  @override
  String toString() {
    return 'Participant{id: $id, studienID:$studienID, age: $age, bangleID: $bangleID, birthday: $birthday, worn_at: $worn_at, bctGroup: $bctGroup, gender: $gender }';
  }
}

Participant fromStringList(List input) {
  Participant p = Participant(
      studienID: input[1],
      age: int.parse(input[2]),
      bangleID: input[3],
      birthday: input[4],
      worn_at: input[5],
      bctGroup: input[6].toLowerCase() == 'true',
      gender: input[7]);
  return p;
}