import 'package:flutter_test/flutter_test.dart';
import 'package:trosky_core/trosky_core.dart';

void main() {
  const r = LogRedactor();

  group('redactHeaders', () {
    test('masks sensitive headers case-insensitively', () {
      final out = r.redactHeaders({
        'authorization': 'Bearer abc.def.ghi',
        'Authorization': 'Bearer another',
        'X-Refresh-Token': 'xyz',
        'Cookie': 'a=1',
        'Content-Type': 'application/json',
      });
      expect(out['authorization'], '<redacted>');
      expect(out['Authorization'], '<redacted>');
      expect(out['X-Refresh-Token'], '<redacted>');
      expect(out['Cookie'], '<redacted>');
      expect(out['Content-Type'], 'application/json');
    });

    test('a safe header like platform keeps its value', () {
      final out = r.redactHeaders({'platform': 'android'});
      expect(out['platform'], 'android');
    });
  });

  group('redactUri', () {
    test('masks token and refresh_token in query', () {
      final uri = Uri.parse(
        'wss://api.trosky.africa/trips/live?trip=1&token=sekret&refresh_token=rr',
      );
      final s = r.redactUri(uri);
      expect(s, contains('token=%3Credacted%3E'));
      expect(s, contains('refresh_token=%3Credacted%3E'));
      expect(s, contains('trip=1'));
    });

    test('a URI without query is passed through unchanged', () {
      final uri = Uri.parse('https://api.trosky.africa/users/me');
      expect(r.redactUri(uri), uri.toString());
    });
  });

  group('redactString', () {
    test('masks a Ghana phone in +233 and 024 forms', () {
      expect(
        r.redactString('SMS to +233244123456 failed'),
        'SMS to <phone-redacted> failed',
      );
      expect(
        r.redactString('received from 0241234567'),
        'received from <phone-redacted>',
      );
    });

    test('masks an email', () {
      expect(
        r.redactString('to Joe.User+tag@gmail.com - 404'),
        'to <email-redacted> - 404',
      );
    });

    test('masks a lat/lng pair', () {
      expect(
        r.redactString('user at 5.5600, -0.2057'),
        'user at <coord-redacted>',
      );
    });

    test('masks a JWT-shaped bearer', () {
      final token = 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.sIG5oUy0ZQ8qqrr';
      expect(
        r.redactString('Authorization: $token'),
        'Authorization: <bearer-redacted>',
      );
    });

    test('empty / null in → empty out', () {
      expect(r.redactString(null), '');
      expect(r.redactString(''), '');
    });
  });
}
