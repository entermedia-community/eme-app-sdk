class CustomException implements Exception {
  final dynamic _message;
  final dynamic _prefix;

  CustomException([this._message, this._prefix]);

  @override
  String toString() {
    return "$_prefix$_message";
  }
}

class FetchDataException extends CustomException {
  FetchDataException([String message = "Unknown Comm Err0r"])
      : super(message, "Error During Communication: ");
}

class BadRequestException extends CustomException {
  BadRequestException([dynamic message]) : super(message, "Invalid Request: ");
}

class UnauthorisedException extends CustomException {
  UnauthorisedException([dynamic message])
      : super(message, "Unauthorised Request: ");
}
