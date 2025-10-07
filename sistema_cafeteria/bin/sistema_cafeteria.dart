import 'dart:async';

enum EstadoPreparacion { pendiente, enProgreso, completado, error }

abstract interface class Preparable {
  Stream<String> preparar();
}

abstract interface class Imprimible {
  String getDescripcion();
}

mixin ParaLlevar {
  bool esParaLlevar = false;

  void empacar() {
    esParaLlevar = true;
    print('   [Pack] Empacando el pedido para llevar... ');
  }
}

abstract class Bebida implements Preparable, Imprimible {
  final String nombre;
  final double precio;

  Bebida(this.nombre, this.precio);

  @override
  String getDescripcion() {
    return '$nombre (\$${precio.toStringAsFixed(2)})';
  }
}

class Cafe extends Bebida with ParaLlevar {
  final bool dobleShot;

  Cafe({required this.dobleShot, required bool llevar})
    : super(
        dobleShot ? 'Café Doble' : 'Café Regular',
        dobleShot ? 3.50 : 2.50,
      ) {
    if (llevar) empacar();
  }

  @override
  String getDescripcion() {
    final llevarTxt = esParaLlevar ? ' (P. Llevar)' : '';
    return super.getDescripcion() + llevarTxt;
  }

  @override
  Stream<String> preparar() async* {
    yield 'Moliendo granos...';
    await Future.delayed(Duration(seconds: 1));
    yield 'Extrayendo shot ${dobleShot ? 'doble' : 'simple'}...';
    await Future.delayed(Duration(seconds: 1));
    yield ' Café listo.';
  }
}

class Te extends Bebida {
  final String sabor;

  Te({required this.sabor}) : super('Té de $sabor', 1.80);

  @override
  Stream<String> preparar() async* {
    yield 'Calentando agua...';
    await Future.delayed(Duration(milliseconds: 500));
    yield 'Infusionando $sabor...';
    await Future.delayed(Duration(milliseconds: 500));
    yield ' Té listo.';
  }
}

class Smoothie extends Bebida {
  final List<String> frutas;

  Smoothie({required this.frutas})
    : super('Smoothie de ${frutas.join(', ')}', 4.50);

  @override
  Stream<String> preparar() async* {
    yield 'Pesando y cortando frutas (${frutas.join(', ')})...';
    await Future.delayed(Duration(seconds: 2));
    yield '¡Licuando con hielo! ';
    await Future.delayed(Duration(seconds: 1));
    yield '✅ Smoothie listo.';
  }
}

class Pastel {
  final String nombre;
  final double precio;
  Pastel(this.nombre, this.precio);
}

class Pedido {
  final int id = DateTime.now().millisecondsSinceEpoch % 10000;

  final List<dynamic> items;

  final _progresoController = StreamController<String>();

  Stream<String> get streamProgreso => _progresoController.stream;

  EstadoPreparacion _estado;

  Pedido(this.items) : _estado = EstadoPreparacion.pendiente;

  Future<void> procesarPedido() async {
    _estado = EstadoPreparacion.enProgreso;
    // ignore: unnecessary_brace_in_string_interps
    _progresoController.add('TICKET #${id}: Iniciando preparación...');

    final List<Future<void>> tareasDePreparacion = [];

    for (final item in items) {
      if (item is Bebida) {
        tareasDePreparacion.add(_procesarBebida(item));
      } else if (item is Pastel) {
        _progresoController.add(
          ' > Sirviendo Pastel: ${item.nombre}. (Instantáneo)',
        );
      }
    }

    await Future.wait(tareasDePreparacion);

    _estado = EstadoPreparacion.completado;
    // ignore: unnecessary_brace_in_string_interps
    _progresoController.add('--- Pedido #${id} COMPLETADO ---');

    await _progresoController.close();
  }

  Future<void> _procesarBebida(Bebida bebida) async {
    _progresoController.add(' > [Bebida ${bebida.nombre}] Iniciando...');

    await for (final mensaje in bebida.preparar()) {
      _progresoController.add('   [${bebida.nombre}]: $mensaje');
    }
  }

  String getTicket() {
    double total = 0;
    String detalles = '--- Detalles del Pedido #$id ---\n';

    for (final item in items) {
      if (item is Bebida) {
        detalles += '- ${item.getDescripcion()}\n';
        total += item.precio;
      } else if (item is Pastel) {
        detalles +=
            '- ${item.nombre} (Postre): \$${item.precio.toStringAsFixed(2)}\n';
        total += item.precio;
      }
    }

    detalles += '------------------------------------\n';
    detalles += 'TOTAL A PAGAR: \$${total.toStringAsFixed(2)}\n';
    detalles += 'Estado: ${_estado.name.toUpperCase()}\n';
    return detalles;
  }
}

void main() async {
  print('--- Sistema de Pedidos de Cafetería (Dart Avanzado) ---');

  final cafeDoble = Cafe(dobleShot: true, llevar: true);
  final teLimon = Te(sabor: 'Limón');
  final smoothieFresa = Smoothie(frutas: ['Fresa', 'Banana']);
  final pastel = Pastel('Cheesecake', 3.00);

  final pedido = Pedido([cafeDoble, teLimon, smoothieFresa, pastel]);

  print('\n${pedido.getTicket()}');

  print('INICIANDO PROCESO ASÍNCRONO CONCURRENTE...');

  pedido.streamProgreso.listen((mensaje) {
    print(' [NOTIFICACIÓN PEDIDO #${pedido.id}]: $mensaje');
  });

  await pedido.procesarPedido();

  print('\n${pedido.getTicket()}');
  print('--- Proceso Finalizado.  ---');
}
