class SingletonOne {

  SingletonOne._privateConstructor();

  static final SingletonOne _instance = SingletonOne._privateConstructor();

  factory SingletonOne() {
    return _instance;
  }

}