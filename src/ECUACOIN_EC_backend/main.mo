import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Time "mo:base/Time";

actor MiCriptomoneda {
  // =============================================
  // SECCIÓN 1: CONFIGURACIÓN INICIAL Y SEGURIDAD
  // =============================================

  private let owner : Principal = Principal.fromText("slrix-y3ldl-pg6nt-46eve-dsfoy-rlowu-w3odj-cwqzb-szpjw-7eqq7-3ae");
  private var maxSupply : Nat = 1_000_000;
  private var totalMinted : Nat = 0;
  private var totalBurned : Nat = 0;

  // Roles de usuario: cliente normal, comerciante pendiente de aprobación, comerciante aprobado
  type RolUsuario = { #cliente; #comercianteP; #comerciante };

  type Usuario = {
    nombre: Text;
    saldo: Nat;
    rol: RolUsuario;
  };

  type Transaccion = {
    id: Nat;
    remitente: Principal;
    destinatario: Principal;
    monto: Nat;
    timestamp: Int;
  };

  type TransferEvent = {
    from: Principal;
    to: Principal;
    amount: Nat;
    timestamp: Int;
  };

  // Un "cobro" es una solicitud de pago que crea un comerciante para que un cliente la pague
  type Cobro = {
    id: Nat;
    comerciante: Principal;
    monto: Nat;
    pagado: Bool;
    timestamp: Int;
  };

  var usuarios = HashMap.HashMap<Principal, Usuario>(10, Principal.equal, Principal.hash);
  var transacciones = Buffer.Buffer<Transaccion>(10);
  var transferEvents = Buffer.Buffer<TransferEvent>(0);
  var cobros = Buffer.Buffer<Cobro>(10);
  var siguienteIdTransaccion: Nat = 0;
  var siguienteIdCobro: Nat = 0;

  // =============================================
  // SECCIÓN 2: FUNCIONES DEL OWNER (RESTRINGIDAS)
  // =============================================

  public shared(msg) func mint(to: Principal, amount: Nat) : async Result.Result<Text, Text> {
    if (msg.caller != owner) {
      return #err("No autorizado: solo el owner puede mintear tokens");
    };

    if (totalMinted + amount > maxSupply) {
      return #err("Error: se excede el suministro máximo de tokens");
    };

    switch (usuarios.get(to)) {
      case (?user) {
        usuarios.put(to, { user with saldo = user.saldo + amount });
      };
      case (null) {
        usuarios.put(to, { nombre = "Nuevo usuario"; saldo = amount; rol = #cliente });
      };
    };

    totalMinted += amount;
    Debug.print("Tokens minteados: " # debug_show(amount) # " para " # Principal.toText(to));
    return #ok("Tokens minteados exitosamente");
  };

  public shared(msg) func setMaxSupply(newSupply: Nat) : async Result.Result<Text, Text> {
    assert(msg.caller == owner);
    maxSupply := newSupply;
    #ok("Suministro máximo actualizado");
  };

  // =============================================
  // SECCIÓN 3: TOKENOMICS (QUEMA DE TOKENS)
  // =============================================

  public shared(msg) func burn(amount: Nat) : async Result.Result<Text, Text> {
    switch (usuarios.get(msg.caller)) {
      case (?user) {
        if (user.saldo < amount) {
          return #err("Error: saldo insuficiente para quemar");
        };

        usuarios.put(msg.caller, { user with saldo = user.saldo - amount });
        totalBurned += amount;

        Debug.print("Tokens quemados: " # debug_show(amount) # " por " # Principal.toText(msg.caller));
        return #ok("Tokens quemados exitosamente");
      };
      case (null) {
        return #err("Error: usuario no encontrado");
      };
    };
  };

  public shared query func getTokenStats() : async {
    maxSupply: Nat;
    totalMinted: Nat;
    totalBurned: Nat;
    circulatingSupply: Nat;
  } {
    {
      maxSupply = maxSupply;
      totalMinted = totalMinted;
      totalBurned = totalBurned;
      circulatingSupply = totalMinted - totalBurned;
    }
  };

  // =============================================
  // SECCIÓN 4: CUENTAS Y TRANSFERENCIAS
  // =============================================

  public shared(msg) func crearCuenta(usuario: Principal, nombre: Text): async Result.Result<Text, Text> {
    if (usuario != msg.caller) {
      return #err("No puedes crear una cuenta a nombre de otro usuario.");
    };

    switch (usuarios.get(usuario)) {
      case (?_) {
        return #err("El usuario ya tiene una cuenta.");
      };
      case (null) {
        if (existeUsuarioPorNombre(nombre)) {
          return #err("El nombre de usuario ya está en uso.");
        };

        usuarios.put(usuario, { nombre = nombre; saldo = 10; rol = #cliente });
        totalMinted += 10;

        Debug.print("Nueva cuenta creada con 10 ECU: " # nombre # " (" # Principal.toText(usuario) # ")");
        return #ok("Cuenta creada con 10 ECU de saldo inicial.");
      };
    };
  };

  public shared(msg) func transferir(destinatario : Principal, monto : Nat) : async Result.Result<Text, Text> {
    let remitente = msg.caller;

    if (remitente == destinatario) {
      return #err("No puedes transferirte a ti mismo");
    };

    if (monto == 0) {
      return #err("El monto debe ser mayor que cero");
    };

    switch (usuarios.get(remitente), usuarios.get(destinatario)) {
      case (?remitenteObj, ?destinatarioObj) {
        if (remitenteObj.saldo < monto) {
          return #err("Saldo insuficiente");
        };

        let nuevoSaldoRemitente = remitenteObj.saldo - monto;
        let nuevoSaldoDestinatario = destinatarioObj.saldo + monto;

        usuarios.put(remitente, { remitenteObj with saldo = nuevoSaldoRemitente });
        usuarios.put(destinatario, { destinatarioObj with saldo = nuevoSaldoDestinatario });

        let nuevaTransaccion = {
          id = siguienteIdTransaccion;
          remitente;
          destinatario;
          monto;
          timestamp = Time.now();
        };
        transacciones.add(nuevaTransaccion);
        siguienteIdTransaccion += 1;

        transferEvents.add({
          from = remitente;
          to = destinatario;
          amount = monto;
          timestamp = Time.now();
        });

        return #ok("Transferencia exitosa");
      };
      case (null, _) {
        return #err("No estás registrado en el sistema");
      };
      case (_, null) {
        return #err("El destinatario no existe");
      };
    };
  };

  // =============================================
  // SECCIÓN 5: ROL DE COMERCIANTE
  // =============================================

  // El usuario pide convertirse en comerciante. Queda pendiente hasta que el owner lo apruebe.
  public shared(msg) func solicitarSerComerciante() : async Result.Result<Text, Text> {
    switch (usuarios.get(msg.caller)) {
      case (?user) {
        switch (user.rol) {
          case (#comerciante) { return #err("Ya eres un comerciante aprobado") };
          case (#comercianteP) { return #err("Tu solicitud ya está pendiente de aprobación") };
          case (#cliente) {
            usuarios.put(msg.caller, { user with rol = #comercianteP });
            return #ok("Solicitud enviada. Espera la aprobación.");
          };
        };
      };
      case (null) { return #err("Debes registrarte primero") };
    };
  };

  // Solo el owner puede aprobar. Cambia #comercianteP -> #comerciante
  public shared(msg) func aprobarComerciante(usuario: Principal) : async Result.Result<Text, Text> {
    if (msg.caller != owner) {
      return #err("No autorizado: solo el owner puede aprobar comerciantes");
    };

    switch (usuarios.get(usuario)) {
      case (?user) {
        usuarios.put(usuario, { user with rol = #comerciante });
        return #ok("Comerciante aprobado");
      };
      case (null) { return #err("Usuario no encontrado") };
    };
  };

  // Lista solicitudes pendientes, para el panel del owner
  public shared query func listarPendientes() : async [(Principal, Usuario)] {
    Iter.toArray(
      Iter.filter<(Principal, Usuario)>(
        usuarios.entries(),
        func ((_, u) : (Principal, Usuario)) : Bool { u.rol == #comercianteP }
      )
    )
  };

  // Solo un comerciante aprobado puede generar un cobro
  public shared(msg) func generarCobro(monto: Nat) : async Result.Result<Nat, Text> {
    switch (usuarios.get(msg.caller)) {
      case (?user) {
        if (user.rol != #comerciante) {
          return #err("Solo comerciantes aprobados pueden generar cobros");
        };
        if (monto == 0) {
          return #err("El monto debe ser mayor que cero");
        };

        let cobro : Cobro = {
          id = siguienteIdCobro;
          comerciante = msg.caller;
          monto;
          pagado = false;
          timestamp = Time.now();
        };
        cobros.add(cobro);
        siguienteIdCobro += 1;
        return #ok(cobro.id);
      };
      case (null) { return #err("Debes registrarte primero") };
    };
  };

  // Cualquier cliente paga un cobro existente por su ID
  public shared(msg) func pagarCobro(cobroId: Nat) : async Result.Result<Text, Text> {
    let cliente = msg.caller;
    var encontrado = false;
    var mensaje = "";
    let nuevosCobros = Buffer.Buffer<Cobro>(cobros.size());

    for (c in cobros.vals()) {
      if (c.id == cobroId and not encontrado) {
        encontrado := true;

        if (c.pagado) {
          mensaje := "Este cobro ya fue pagado";
          nuevosCobros.add(c);
        } else if (c.comerciante == cliente) {
          mensaje := "No puedes pagar tu propio cobro";
          nuevosCobros.add(c);
        } else {
          switch (usuarios.get(cliente), usuarios.get(c.comerciante)) {
            case (?clienteObj, ?comercianteObj) {
              if (clienteObj.saldo < c.monto) {
                mensaje := "Saldo insuficiente";
                nuevosCobros.add(c);
              } else {
                usuarios.put(cliente, { clienteObj with saldo = clienteObj.saldo - c.monto });
                usuarios.put(c.comerciante, { comercianteObj with saldo = comercianteObj.saldo + c.monto });

                transacciones.add({
                  id = siguienteIdTransaccion;
                  remitente = cliente;
                  destinatario = c.comerciante;
                  monto = c.monto;
                  timestamp = Time.now();
                });
                siguienteIdTransaccion += 1;

                nuevosCobros.add({ c with pagado = true });
                mensaje := "ok";
              };
            };
            case (_, _) {
              mensaje := "Error al procesar el pago";
              nuevosCobros.add(c);
            };
          };
        };
      } else {
        nuevosCobros.add(c);
      };
    };

    cobros := nuevosCobros;

    if (not encontrado) { return #err("Cobro no encontrado") };
    if (mensaje == "ok") { return #ok("Pago realizado con éxito") };
    return #err(mensaje);
  };

  // Consulta el rol actual de un usuario (útil para el frontend)
  public shared query func consultarRol(usuario: Principal): async Text {
    switch (usuarios.get(usuario)) {
      case (?user) {
        switch (user.rol) {
          case (#cliente) { "cliente" };
          case (#comercianteP) { "comercianteP" };
          case (#comerciante) { "comerciante" };
        }
      };
      case (null) { "no registrado" };
    }
  };

  // Consulta un cobro por ID
  public shared query func consultarCobro(cobroId: Nat): async ?Cobro {
    for (c in cobros.vals()) {
      if (c.id == cobroId) { return ?c };
    };
    null
  };

  // Lista los cobros generados por un comerciante específico
  public shared query func listarCobrosDe(comerciante: Principal): async [Cobro] {
    Iter.toArray(
      Iter.filter<Cobro>(
        cobros.vals(),
        func (c : Cobro) : Bool { c.comerciante == comerciante }
      )
    )
  };

  // =============================================
  // SECCIÓN 6: FUNCIONES DE CONSULTA (QUERY)
  // =============================================

  func existeUsuarioPorNombre(nombre: Text): Bool {
    for ((_, user) in usuarios.entries()) {
      if (user.nombre == nombre) {
        return true;
      }
    };
    false
  };

  public shared query func usuarioExiste(usuario: Principal): async Bool {
    switch (usuarios.get(usuario)) {
      case (null) { false };
      case (?_) { true };
    }
  };

  public shared query func consultarNombre(usuario: Principal): async Text {
    switch (usuarios.get(usuario)) {
      case (?user) { user.nombre };
      case (null) { "Usuario no encontrado" };
    }
  };

  public shared query func consultarSaldo(usuario: Principal): async Nat {
    switch (usuarios.get(usuario)) {
      case (?user) { user.saldo };
      case (null) { 0 };
    }
  };

  public shared query func consultarTransacciones(): async [Transaccion] {
    Buffer.toArray(transacciones)
  };

  public shared query func listarUsuarios(): async [(Principal, Usuario)] {
    Iter.toArray(usuarios.entries())
  };

  public shared query func consultarEventos(): async [TransferEvent] {
    Buffer.toArray(transferEvents)
  };
};