import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigilancia_durazno/core/utils/canonical_json.dart';

/// Contrato compartido de la huella de contenido (R-T4, RN-010).
///
/// Los vectores son los mismos que usa el backend; si esta prueba falla, móvil y
/// servidor ya no calculan la misma huella y el servidor rechazaría todo.
void main() {
  final documento = jsonDecode(
    File('test/vectores_huella.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final vectores = (documento['vectores'] as List).cast<Map<String, dynamic>>();
  final normalizacion = (documento['normalizacion_instante'] as List)
      .cast<Map<String, dynamic>>();

  test('los vectores declaran el algoritmo acordado', () {
    final algoritmo = documento['algoritmo'] as Map<String, dynamic>;
    expect(algoritmo['canonicalizacion'], 'RFC 8785 (JCS)');
    expect(algoritmo['hash'], 'sha256');
    expect(vectores, hasLength(greaterThanOrEqualTo(5)));
  });

  for (final vector in vectores) {
    test('huella: ${vector['nombre']}', () {
      expect(
        CanonicalJson.sha256Hex(vector['contenido']),
        vector['hash'],
        reason: 'El texto canónico del móvil no coincide con el del backend.',
      );
    });
  }

  for (final vector in normalizacion) {
    test('instante canónico: ${vector['entrada']}', () {
      final entrada = DateTime.parse(vector['entrada'] as String);
      expect(CanonicalJson.instanteCanonico(entrada), vector['canonica']);
    });
  }

  test('el orden de las claves no cambia la huella', () {
    final a = {
      'b': 2,
      'a': 1,
      'c': {'z': true, 'y': null}
    };
    final b = {
      'c': {'y': null, 'z': true},
      'a': 1,
      'b': 2
    };
    expect(CanonicalJson.serialize(a), CanonicalJson.serialize(b));
    expect(CanonicalJson.serialize(a), '{"a":1,"b":2,"c":{"y":null,"z":true}}');
  });

  test('los números siguen el formato de ECMAScript (JCS)', () {
    expect(CanonicalJson.serialize(1.0), '1');
    expect(CanonicalJson.serialize(1.5), '1.5');
    expect(CanonicalJson.serialize(0.000001), '0.000001');
    expect(CanonicalJson.serialize(1e-7), '1e-7');
    expect(CanonicalJson.serialize(1e21), '1e+21');
    expect(CanonicalJson.serialize(-0.0), '0');
    expect(CanonicalJson.serialize(2.5e-8), '2.5e-8');
  });

  test('las cadenas conservan Unicode y escapan solo lo que exige JSON', () {
    expect(
      CanonicalJson.serialize({'zona': 'Trampa «A» ñ', 'l': 'Borde — revisar'}),
      '{"l":"Borde — revisar","zona":"Trampa «A» ñ"}',
    );
  });

  test('uuidDesdeSemilla es estable y tiene forma de UUID', () {
    final primera = CanonicalJson.uuidDesdeSemilla('visita:abc:predio:3');
    final segunda = CanonicalJson.uuidDesdeSemilla('visita:abc:predio:3');
    final otra = CanonicalJson.uuidDesdeSemilla('visita:abc:predio:4');
    final forma = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

    expect(primera, segunda);
    expect(primera, isNot(otra));
    expect(forma.hasMatch(primera), isTrue, reason: primera);
  });

  test('generarUuidV4 produce valores distintos con versión 4', () {
    final forma = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final valores = {
      for (var i = 0; i < 50; i++) CanonicalJson.generarUuidV4()
    };
    expect(valores, hasLength(50));
    expect(valores.every(forma.hasMatch), isTrue);
  });
}
