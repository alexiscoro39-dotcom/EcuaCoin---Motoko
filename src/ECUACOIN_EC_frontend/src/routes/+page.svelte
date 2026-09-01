<script>
  import { AuthClient } from '@dfinity/auth-client';
  import { Principal } from '@dfinity/principal';
  import { backend, setIdentity } from '$lib/canisters';
  import './styles.css';

  // Variables de estado
  let authClient;
  let identity;
  let isLoading = false;
  let isTransferring = false;
  let errorMessage = '';
  let principalId = '';
  let nombreUsuario = '';
  let saldo = 0;
  let balanceEstimado = 0;
  let destinatarioId = '';
  let montoTransferencia = '';
  let mensajeTransferencia = '';
  let mostrarFormularioRegistro = false;
  let rolUsuario = 'cliente'; // cliente | comercianteP | comerciante
  let ocultarPantallaSolicitud = false;
  let seccion = 'dashboard'; // 'dashboard' | 'admin' | 'comercio'
  let solicitudesPendientes = [];
  let cargandoPendientes = false;
  let montoCobro = '';
  let cobrosGenerados = [];
  let cargandoCobros = false;
  let generandoCobro = false;
  let mensajeCobro = '';
  const precioCripto = 1;
  const OWNER_PRINCIPAL = 'slrix-y3ldl-pg6nt-46eve-dsfoy-rlowu-w3odj-cwqzb-szpjw-7eqq7-3ae';
  $: esOwner = principalId === OWNER_PRINCIPAL;

  async function initAuth() {
    isLoading = true;
    errorMessage = '';
    try {
      authClient = await AuthClient.create();

      if (await authClient.isAuthenticated()) {
        identity = authClient.getIdentity();
        principalId = identity.getPrincipal().toText();
        await setIdentity(identity);
        await verificarUsuario();
        return;
      }

      await authClient.login({
        identityProvider: 'http://be2us-64aaa-aaaaa-qaabq-cai.localhost:4943',
        onSuccess: async () => {
          identity = authClient.getIdentity();
          principalId = identity.getPrincipal().toText();
          await setIdentity(identity);
          await verificarUsuario();
        },
        onError: (error) => {
          errorMessage = `Error: ${error.message || 'Desconocido'}`;
        }
      });
    } catch (error) {
      errorMessage = 'Error al iniciar sesión';
      console.error("Error detallado:", error);
    } finally {
      isLoading = false;
    }
  }

  async function verificarUsuario() {
    try {
      const existe = await backend.usuarioExiste(identity.getPrincipal());
      mostrarFormularioRegistro = !existe;
      if (existe) await actualizarDatosUsuario();
    } catch (error) {
      errorMessage = 'Error al verificar usuario';
    }
  }

  async function registrarUsuario() {
    if (!nombreUsuario.trim()) {
      errorMessage = 'Nombre no válido';
      return;
    }

    try {
      const resultado = await backend.crearCuenta(
        identity.getPrincipal(),
        nombreUsuario.trim()
      );

      if ('ok' in resultado) {
        mostrarFormularioRegistro = false;
        await actualizarDatosUsuario();
      } else {
        errorMessage = resultado.err;
      }
    } catch (error) {
      errorMessage = 'Error al registrar';
    }
  }

  async function actualizarDatosUsuario() {
    try {
      const [nombre, saldoActual, rol] = await Promise.all([
        backend.consultarNombre(identity.getPrincipal()),
        backend.consultarSaldo(identity.getPrincipal()),
        backend.consultarRol(identity.getPrincipal())
      ]);

      nombreUsuario = nombre;
      saldo = Number(saldoActual);
      balanceEstimado = saldo * precioCripto;
      rolUsuario = rol;
    } catch (error) {
      console.error("Error actualizando datos:", error);
    }
  }

  async function solicitarComercio() {
    try {
      const resultado = await backend.solicitarSerComerciante();
      if ('ok' in resultado) {
        rolUsuario = 'comercianteP';
        ocultarPantallaSolicitud = false;
      } else {
        errorMessage = resultado.err;
      }
    } catch (error) {
      errorMessage = 'Error al solicitar';
    }
  }

  function copiarId() {
    navigator.clipboard.writeText(principalId);
  }

  async function irAdmin() {
    seccion = 'admin';
    await cargarPendientes();
  }

  async function cargarPendientes() {
    cargandoPendientes = true;
    try {
      solicitudesPendientes = await backend.listarPendientes();
    } catch (error) {
      console.error(error);
    } finally {
      cargandoPendientes = false;
    }
  }

  async function aprobar(principal) {
    try {
      const resultado = await backend.aprobarComerciante(principal);
      if ('ok' in resultado) {
        await cargarPendientes();
      } else {
        errorMessage = resultado.err;
      }
    } catch (error) {
      errorMessage = 'Error al aprobar';
    }
  }

  async function irComercio() {
    seccion = 'comercio';
    await cargarCobros();
  }

  async function cargarCobros() {
    cargandoCobros = true;
    try {
      const lista = await backend.listarCobrosDe(identity.getPrincipal());
      cobrosGenerados = [...lista].reverse();
    } catch (error) {
      console.error(error);
    } finally {
      cargandoCobros = false;
    }
  }

  async function generarCobroHandler() {
    const monto = Number(montoCobro);
    if (isNaN(monto) || monto <= 0) {
      mensajeCobro = '❌ Ingresa un monto válido';
      return;
    }
    generandoCobro = true;
    mensajeCobro = '';
    try {
      const resultado = await backend.generarCobro(BigInt(monto));
      if ('ok' in resultado) {
        mensajeCobro = `✅ Cobro #${resultado.ok} generado`;
        montoCobro = '';
        await cargarCobros();
      } else {
        mensajeCobro = `❌ ${resultado.err}`;
      }
    } catch (error) {
      mensajeCobro = '❌ Error al generar el cobro';
    } finally {
      generandoCobro = false;
    }
  }

  function formatFecha(timestampNanos) {
    const ms = Number(timestampNanos / 1000000n);
    return new Date(ms).toLocaleString('es-EC', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
  }

    let cobroIdBuscar = '';
  let cobroEncontrado = null;
  let buscandoCobro = false;
  let pagandoCobro = false;
  let mensajePago = '';
  let pagoExitosoInfo = null;

  function irPagar() {
    seccion = 'pagar';
    cobroIdBuscar = '';
    cobroEncontrado = null;
    mensajePago = '';
  }

    async function buscarCobro() {
    if (cobroIdBuscar === '' || cobroIdBuscar === null || cobroIdBuscar === undefined) return;
    buscandoCobro = true;
    mensajePago = '';
    cobroEncontrado = null;
    try {
      const resultado = await backend.consultarCobro(BigInt(cobroIdBuscar));
      if (resultado.length === 0) {
        mensajePago = '❌ Cobro no encontrado';
      } else {
        const cobro = resultado[0];
        const nombreComerciante = await backend.consultarNombre(cobro.comerciante);
        cobroEncontrado = { ...cobro, nombreComerciante };
      }
    } catch (error) {
      console.error('[buscarCobro]', error);
      mensajePago = '❌ Error al buscar el cobro';
    } finally {
      buscandoCobro = false;
    }
  }

  async function pagarCobroHandler() {
    if (!cobroEncontrado) return;
    pagandoCobro = true;
    mensajePago = '';
    try {
      const resultado = await backend.pagarCobro(cobroEncontrado.id);
      if ('ok' in resultado) {
        pagoExitosoInfo = {
          monto: cobroEncontrado.monto.toString(),
          nombreComerciante: cobroEncontrado.nombreComerciante,
          id: cobroEncontrado.id.toString()
        };
        seccion = 'pago-exitoso';
        await actualizarDatosUsuario();
      } else {
        mensajePago = `❌ ${resultado.err}`;
      }
    } catch (error) {
      mensajePago = '❌ Error al pagar';
    } finally {
      pagandoCobro = false;
    }
  }

  async function realizarTransferencia(event) {
    event.preventDefault();
    isTransferring = true;
    mensajeTransferencia = '';

    try {
        if (!destinatarioId.trim()) {
            throw new Error("Ingresa un ID de destinatario válido");
        }

        const monto = Number(montoTransferencia);
        if (isNaN(monto) || monto <= 0) {
            throw new Error("El monto debe ser mayor a 0");
        }

        const destinatario = Principal.fromText(destinatarioId.trim());
        const remitente = identity.getPrincipal();

        if (remitente.toText() === destinatario.toText()) {
            throw new Error("No puedes enviarte tokens a ti mismo");
        }

        const saldoActual = await backend.consultarSaldo(remitente);
        if (Number(saldoActual) < monto) {
            throw new Error(`Saldo insuficiente. Tienes ${saldoActual} ECU`);
        }

        const resultado = await backend.transferir(destinatario, BigInt(monto));

        if ('err' in resultado) {
            throw new Error(resultado.err);
        }

        mensajeTransferencia = "✅ Transferencia exitosa!";
        destinatarioId = "";
        montoTransferencia = "";
        await actualizarDatosUsuario();

    } catch (error) {
        console.error("[ERROR] Detalles:", error);
        mensajeTransferencia = `❌ ${error.message}`;
    } finally {
        isTransferring = false;
    }
  }

  async function cerrarSesion() {
    await authClient?.logout();
    authClient = null;
    identity = null;
    principalId = '';
    nombreUsuario = '';
    saldo = 0;
    balanceEstimado = 0;
  }
</script>

<main class="min-h-screen bg-gray-100 flex flex-col items-center justify-center p-4">
{#if !authClient}
  <!-- Pantalla de login -->
  <div class="w-full max-w-sm bg-white rounded-3xl shadow-xl p-8 flex flex-col items-center text-center">
    <div class="w-24 h-24 mb-6 rounded-full overflow-hidden bg-gray-100 flex items-center justify-center p-2 shadow-sm ring-1 ring-gray-200/60">
      <img
        alt="Logo ECUACOIN_EC"
        class="w-full h-full object-contain"
        src="https://lh3.googleusercontent.com/aida-public/AB6AXuCIAAsd0zJrCAc54kIgJkJ_-fHuHSxov1-uOzPCYLILSbJxZi4mdMgh0EqvGKoVAMuFf9bAxx32VG34fvcKMVtWdlLJBAmZNFt7rQSkqAuRHM3p21gwcb9QpDElXXDINC4q8SOw7Yfdjh2McGv1ukBvX5d-ygclUI11i0cs46u9ZiiDP5e2F9R0veESotvAdYAus3zuKfVga8cFVSkKiAnn7GFEXzqr1bROsJNdtvgdmig5DeK8d0o"
      />
    </div>

    <h1 class="text-xl font-bold text-gray-900 mb-2 tracking-tight">Bienvenido a ECUACOIN</h1>
    <p class="text-gray-500 text-sm mb-8 max-w-[240px]">Inicia sesión con Internet Identity para acceder a tu billetera financiera.</p>

    {#if isLoading}
      <div class="flex items-center justify-center gap-2 text-gray-500 py-3">
        <svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Cargando...
      </div>
    {:else}
      <button
        on:click={initAuth}
        class="w-full h-14 bg-green-700 text-white font-medium rounded-xl flex items-center justify-center gap-2 shadow-md hover:shadow-lg hover:bg-green-800 transition-all"
      >
        <span class="material-symbols-outlined text-[20px]">fingerprint</span>
        Conectar
      </button>
    {/if}

    {#if errorMessage}
      <p class="text-red-600 mt-4 text-sm">{errorMessage}</p>
    {/if}

    <div class="mt-8 flex items-center justify-center gap-2 text-gray-400">
      <span class="material-symbols-outlined text-[16px]">lock</span>
      <span class="text-xs uppercase tracking-widest">Seguridad de grado bancario</span>
    </div>
  </div>

{:else if mostrarFormularioRegistro}
  <!-- Formulario de registro -->
  <div class="w-full max-w-sm bg-white p-8 rounded-2xl shadow-xl">
    <div class="text-center flex flex-col items-center gap-2 mb-6">
      <div class="w-16 h-16 rounded-2xl bg-primary flex items-center justify-center text-white shadow-lg mb-2">
        <span class="material-symbols-outlined text-[32px]">waving_hand</span>
      </div>
      <h1 class="text-2xl font-bold text-primary tracking-tight">¡Bienvenido!</h1>
      <div class="bg-gray-100 rounded-xl p-4 shadow-sm relative overflow-hidden mt-2">
        <div class="absolute top-0 left-0 w-1 h-full bg-secondary"></div>
        <p class="text-sm text-gray-600 leading-relaxed">
          Al registrarte recibirás <strong class="text-primary font-semibold">10 ECU</strong> como regalo de bienvenida para que empieces a usar la red.
        </p>
      </div>
    </div>

    <div class="flex flex-col gap-2">
      <label class="text-sm text-gray-600 pl-1" for="fullName">Tu nombre completo</label>
      <div class="relative flex items-center">
        <span class="material-symbols-outlined absolute left-4 text-gray-400 z-10">person</span>
        <input
          id="fullName"
          bind:value={nombreUsuario}
          placeholder="Ej: Juan Pérez"
          class="w-full h-14 pl-12 pr-4 bg-white text-gray-900 rounded-xl shadow-sm border border-gray-200 focus:outline-none focus:ring-2 focus:ring-primary transition-shadow"
        />
      </div>
    </div>

    {#if errorMessage}
      <p class="text-red-600 text-sm mt-3">{errorMessage}</p>
    {/if}

    <button
      on:click={registrarUsuario}
      class="w-full h-14 mt-6 bg-secondary text-white font-semibold rounded-xl shadow-md hover:shadow-lg active:scale-[0.98] transition-all flex items-center justify-center gap-2"
    >
      Guardar
      <span class="material-symbols-outlined text-[20px]">arrow_forward</span>
    </button>

    <button
      on:click={cerrarSesion}
      class="w-full h-12 mt-3 text-gray-500 text-sm hover:text-gray-700 transition-colors"
    >
      Cerrar sesión
    </button>
  </div>

{:else if rolUsuario === 'comercianteP' && !ocultarPantallaSolicitud}
  <!-- Estado de solicitud -->
  <div class="w-full max-w-sm bg-white rounded-3xl shadow-xl p-8 flex flex-col items-center text-center">
    <div class="relative mb-4">
      <div class="w-20 h-20 rounded-full bg-primary flex items-center justify-center">
        <span class="material-symbols-outlined text-white text-[36px]">store</span>
      </div>
      <div class="absolute -bottom-1 -right-1 w-7 h-7 rounded-full bg-yellow-400 flex items-center justify-center border-2 border-white">
        <span class="material-symbols-outlined text-white text-[16px]">hourglass_top</span>
      </div>
    </div>

    <h1 class="text-xl font-bold text-primary mb-2">Solicitud Recibida</h1>
    <p class="text-gray-500 text-sm mb-6">
      Tu perfil para convertirte en comerciante verificado está bajo revisión. Te notificaremos pronto.
    </p>

    <div class="w-full bg-gray-50 rounded-xl p-4 mb-6">
      <p class="text-sm font-semibold text-gray-800 mb-1">Estado: <span class="text-primary">Pendiente de aprobación</span></p>
      <p class="text-xs text-gray-500 mb-4">Un administrador revisará tu solicitud.</p>

      <div class="flex items-center">
        <div class="flex-1 h-1.5 rounded-full bg-primary"></div>
        <div class="flex-1 h-1.5 rounded-full bg-gray-200 ml-1"></div>
      </div>
      <div class="flex justify-between mt-2">
        <span class="text-[10px] uppercase tracking-wide text-primary font-semibold">Enviado</span>
        <span class="text-[10px] uppercase tracking-wide text-gray-400 font-semibold">Aprobado</span>
      </div>
    </div>

    <button
      on:click={() => ocultarPantallaSolicitud = true}
      class="w-full h-12 bg-primary text-white font-medium rounded-xl flex items-center justify-center gap-2 hover:bg-primary/90 transition-colors"
    >
      <span class="material-symbols-outlined text-[18px]">arrow_back</span>
      Volver al inicio
    </button>

    <p class="text-[10px] text-gray-400 mt-4 font-mono">ID: {principalId.slice(0, 12)}...</p>
  </div>

{:else}
  <!-- Dashboard principal -->
  <div class="w-full max-w-4xl space-y-6">

    <div class="flex items-center justify-between">
      <div class="flex items-center gap-3">
        <img alt="Logo ECUACOIN_EC" class="h-9 w-9 rounded-full" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCIAAsd0zJrCAc54kIgJkJ_-fHuHSxov1-uOzPCYLILSbJxZi4mdMgh0EqvGKoVAMuFf9bAxx32VG34fvcKMVtWdlLJBAmZNFt7rQSkqAuRHM3p21gwcb9QpDElXXDINC4q8SOw7Yfdjh2McGv1ukBvX5d-ygclUI11i0cs46u9ZiiDP5e2F9R0veESotvAdYAus3zuKfVga8cFVSkKiAnn7GFEXzqr1bROsJNdtvgdmig5DeK8d0o" />
        <span class="font-bold text-primary tracking-tight">ECUACOIN_EC</span>
      </div>
      <nav class="hidden sm:flex items-center gap-6">

        <button
          on:click={() => seccion = 'dashboard'}
          class="text-sm transition-colors"
          class:text-primary={seccion === 'dashboard'}
          class:font-bold={seccion === 'dashboard'}
          class:text-gray-500={seccion !== 'dashboard'}
        >Dashboard</button>

        <button
          on:click={irPagar}
          class="text-sm transition-colors"
          class:text-primary={seccion === 'pagar'}
          class:font-bold={seccion === 'pagar'}
          class:text-gray-500={seccion !== 'pagar'}
        >Pagar</button>


        {#if rolUsuario === 'comerciante'}
          <button
            on:click={irComercio}
            class="text-sm transition-colors"
            class:text-primary={seccion === 'comercio'}
            class:font-bold={seccion === 'comercio'}
            class:text-gray-500={seccion !== 'comercio'}
          >Comercio</button>
        {/if}
        {#if esOwner}
          <button
            on:click={irAdmin}
            class="text-sm transition-colors"
            class:text-primary={seccion === 'admin'}
            class:font-bold={seccion === 'admin'}
            class:text-gray-500={seccion !== 'admin'}
          >Admin</button>
        {/if}
      </nav>
      <button
        on:click={cerrarSesion}
        class="text-sm text-gray-500 hover:text-gray-700 transition-colors"
      >
        Cerrar sesión
      </button>
    </div>

    {#if seccion === 'dashboard'}
      <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <div class="lg:col-span-5 rounded-[2rem] bg-gray-50 shadow-sm p-6 sm:p-8 flex flex-col justify-between min-h-[220px]">
          <div class="flex items-center gap-4 mb-4">
            <div class="w-12 h-12 rounded-full bg-primary flex items-center justify-center shadow-sm">
              <span class="material-symbols-outlined text-white text-[24px]">waving_hand</span>
            </div>
            <div>
              <h1 class="text-lg font-bold text-gray-900">Hola, {nombreUsuario || 'Sin nombre'}</h1>
              <p class="text-sm text-gray-500">Bienvenido de vuelta</p>
            </div>
          </div>
          <div class="bg-white rounded-xl p-4 flex items-center justify-between shadow-sm">
            <div class="flex flex-col overflow-hidden">
              <span class="text-xs text-gray-400 uppercase tracking-wider mb-1">ID de Billetera</span>
              <span class="text-sm text-gray-800 font-mono truncate">{principalId}</span>
            </div>
            <button
              on:click={copiarId}
              aria-label="Copiar ID"
              class="w-10 h-10 shrink-0 rounded-full bg-gray-100 flex items-center justify-center text-primary hover:bg-primary/10 transition-colors ml-2"
            >
              <span class="material-symbols-outlined text-[20px]">content_copy</span>
            </button>
          </div>
        </div>

        <div class="lg:col-span-7 rounded-[2rem] bg-primary shadow-lg p-6 sm:p-8 min-h-[220px] flex flex-col justify-between">
          <div class="flex items-center justify-between">
            <span class="text-xs text-white/70 uppercase tracking-wider flex items-center gap-2">
              <span class="w-2 h-2 rounded-full bg-secondary-fixed animate-pulse"></span>
              Balance Disponible
            </span>
            <span class="material-symbols-outlined text-white/70 text-[24px]">account_balance_wallet</span>
          </div>
          <div class="mt-4">
            <div class="flex items-baseline gap-2">
              <span class="text-5xl font-bold text-white tracking-tighter">{saldo}</span>
              <span class="text-xl font-semibold text-white/70">ECU</span>
            </div>
            <p class="text-white/70 text-sm mt-1">≈ {balanceEstimado.toFixed(2)} USD</p>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <div class="lg:col-span-8 bg-white rounded-[2rem] shadow-sm p-6 sm:p-8">
          <div class="flex items-center justify-between mb-6">
            <div>
              <h2 class="text-lg font-bold text-gray-900 mb-1">Nueva Transferencia</h2>
              <p class="text-sm text-gray-500">Envía fondos de manera segura</p>
            </div>
            <div class="w-12 h-12 rounded-2xl bg-gray-100 flex items-center justify-center text-primary">
              <span class="material-symbols-outlined text-[24px]">send</span>
            </div>
          </div>

          <form on:submit|preventDefault={realizarTransferencia} class="space-y-5">
            <div class="space-y-1">
              <label for="destinatario" class="text-sm text-gray-700 ml-1 block">Destinatario</label>
              <div class="relative">
                <span class="material-symbols-outlined absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">person_search</span>
                <input
                  id="destinatario"
                  bind:value={destinatarioId}
                  placeholder="Principal ID del destinatario"
                  disabled={isTransferring}
                  class="w-full h-14 pl-12 pr-4 bg-gray-50 rounded-xl text-gray-900 focus:outline-none focus:ring-2 focus:ring-primary transition-all border border-gray-200"
                />
              </div>
            </div>

            <div class="space-y-1">
              <label for="monto" class="text-sm text-gray-700 ml-1 block">Monto</label>
              <div class="relative">
                <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 font-semibold">E</span>
                <input
                  id="monto"
                  type="number"
                  bind:value={montoTransferencia}
                  min="1"
                  step="1"
                  disabled={isTransferring}
                  on:input={() => mensajeTransferencia = ''}
                  placeholder="0.00"
                  class="w-full h-14 pl-10 pr-4 bg-gray-50 rounded-xl text-xl font-semibold text-gray-900 focus:outline-none focus:ring-2 focus:ring-primary transition-all border border-gray-200"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={!destinatarioId || !montoTransferencia || isTransferring}
              class="w-full h-14 bg-secondary text-white font-semibold rounded-xl hover:shadow-md transition-all active:scale-[0.98] flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {#if isTransferring}
                <span class="material-symbols-outlined animate-spin text-[20px]">autorenew</span>
                Procesando...
              {:else}
                Transferir ECU
                <span class="material-symbols-outlined text-[20px]">arrow_forward</span>
              {/if}
            </button>

            {#if mensajeTransferencia}
              <div class="p-3 rounded-xl text-center text-sm"
                   class:bg-green-50={mensajeTransferencia.includes('✅')}
                   class:text-green-700={mensajeTransferencia.includes('✅')}
                   class:bg-red-50={mensajeTransferencia.includes('❌')}
                   class:text-red-700={mensajeTransferencia.includes('❌')}>
                {mensajeTransferencia}
              </div>
            {/if}
          </form>
        </div>

        <div class="lg:col-span-4 flex flex-col gap-6">
          {#if rolUsuario === 'cliente'}
            <button
              on:click={solicitarComercio}
              class="group bg-gray-100 rounded-2xl p-5 flex items-center justify-between hover:bg-primary hover:text-white transition-colors duration-300 shadow-sm text-left"
            >
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-full bg-white flex items-center justify-center">
                  <span class="material-symbols-outlined text-gray-500 group-hover:text-primary transition-colors">store</span>
                </div>
                <div class="flex flex-col">
                  <span class="text-sm font-medium text-gray-900 group-hover:text-white transition-colors">¿Tienes un negocio?</span>
                  <span class="text-xs text-gray-500 group-hover:text-white/80 transition-colors">Quiero ser comerciante</span>
                </div>
              </div>
              <span class="material-symbols-outlined text-gray-400 group-hover:text-white transition-colors">chevron_right</span>
            </button>
          {:else if rolUsuario === 'comercianteP'}
            <div class="bg-yellow-50 rounded-2xl p-5 flex items-center gap-3 shadow-sm">
              <span class="material-symbols-outlined text-yellow-600">hourglass_top</span>
              <div>
                <p class="text-sm font-medium text-yellow-800">Solicitud pendiente</p>
                <p class="text-xs text-yellow-700">Un administrador revisará tu solicitud pronto.</p>
              </div>
            </div>
          {:else if rolUsuario === 'comerciante'}
            <button
              on:click={irComercio}
              class="bg-primary/10 rounded-2xl p-5 flex items-center gap-3 shadow-sm text-left hover:bg-primary/20 transition-colors"
            >
              <span class="material-symbols-outlined text-primary">verified</span>
              <div>
                <p class="text-sm font-medium text-primary">Comerciante aprobado</p>
                <p class="text-xs text-gray-600">Ir a generar cobros</p>
              </div>
            </button>
          {/if}

          {#if esOwner}
            <button
              on:click={irAdmin}
              class="bg-gray-900 rounded-2xl p-5 flex items-center gap-3 shadow-sm text-left hover:bg-gray-800 transition-colors"
            >
              <span class="material-symbols-outlined text-white">admin_panel_settings</span>
              <div>
                <p class="text-sm font-medium text-white">Modo administrador</p>
                <p class="text-xs text-gray-300">Aprobar comerciantes pendientes.</p>
              </div>
            </button>
          {/if}
        </div>
      </div>

    {:else if seccion === 'admin' && esOwner}
      <!-- Panel de administrador -->
      <div class="bg-white rounded-[2rem] shadow-sm p-6 sm:p-8">
        <div class="mb-6">
          <h1 class="text-xl font-bold text-gray-900 mb-1">Solicitudes de Comercio Pendientes</h1>
          <p class="text-sm text-gray-500">Revisa y aprueba a los usuarios que quieren cobrar como comerciantes.</p>
        </div>

        {#if cargandoPendientes}
          <p class="text-sm text-gray-500 py-8 text-center">Cargando...</p>
        {:else if solicitudesPendientes.length === 0}
          <div class="py-12 text-center">
            <span class="material-symbols-outlined text-gray-300 text-[48px]">inbox</span>
            <p class="text-gray-400 text-sm mt-2">No hay solicitudes pendientes</p>
          </div>
        {:else}
          <div class="divide-y divide-gray-100">
            {#each solicitudesPendientes as [principal, usuario]}
              <div class="flex items-center justify-between py-4">
                <div class="flex items-center gap-3 min-w-0">
                  <div class="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center shrink-0">
                    <span class="material-symbols-outlined text-gray-500 text-[20px]">storefront</span>
                  </div>
                  <div class="min-w-0">
                    <p class="font-semibold text-gray-900 truncate">{usuario.nombre}</p>
                    <p class="text-xs text-gray-400 font-mono truncate">{principal.toText()}</p>
                  </div>
                </div>
                <button
                  on:click={() => aprobar(principal)}
                  class="h-10 px-4 rounded-lg bg-secondary text-white text-sm font-medium hover:shadow-md transition-all flex items-center gap-1 shrink-0"
                >
                  <span class="material-symbols-outlined text-[18px]">check</span>
                  Aprobar
                </button>
              </div>
            {/each}
          </div>
        {/if}
      </div>

    {:else if seccion === 'comercio' && rolUsuario === 'comerciante'}
      <!-- Panel de comercio -->
      <div class="space-y-6">
        <div class="bg-primary rounded-[2rem] shadow-lg p-6 sm:p-8">
          <h1 class="text-lg font-bold text-white mb-1">Generar nuevo cobro</h1>
          <p class="text-white/70 text-sm mb-5">Ingresa el monto para generar un cobro que tus clientes puedan pagar.</p>

          <div class="flex flex-col sm:flex-row gap-3">
            <div class="relative flex-1">
              <span class="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400 font-semibold">E</span>
              <input
                type="number"
                bind:value={montoCobro}
                min="1"
                step="1"
                placeholder="0.00"
                disabled={generandoCobro}
                class="w-full h-14 pl-10 pr-4 bg-white rounded-xl text-xl font-semibold text-gray-900 focus:outline-none focus:ring-2 focus:ring-secondary transition-all"
              />
            </div>
            <button
              on:click={generarCobroHandler}
              disabled={!montoCobro || generandoCobro}
              class="h-14 px-6 bg-secondary text-white font-semibold rounded-xl hover:shadow-md transition-all active:scale-[0.98] flex items-center justify-center gap-2 disabled:opacity-50 whitespace-nowrap"
            >
              {#if generandoCobro}
                <span class="material-symbols-outlined animate-spin text-[20px]">autorenew</span>
              {:else}
                <span class="material-symbols-outlined text-[20px]">qr_code_2</span>
              {/if}
              Generar cobro
            </button>
          </div>

          {#if mensajeCobro}
            <p class="text-white text-sm mt-3">{mensajeCobro}</p>
          {/if}
        </div>

        <div class="bg-white rounded-[2rem] shadow-sm p-6 sm:p-8">
          <h2 class="text-lg font-bold text-gray-900 mb-4">Cobros Generados</h2>

          {#if cargandoCobros}
            <p class="text-sm text-gray-500 py-8 text-center">Cargando...</p>
          {:else if cobrosGenerados.length === 0}
            <div class="py-12 text-center">
              <span class="material-symbols-outlined text-gray-300 text-[48px]">receipt_long</span>
              <p class="text-gray-400 text-sm mt-2">Aún no has generado cobros</p>
            </div>
          {:else}
            <div class="divide-y divide-gray-100">
              {#each cobrosGenerados as cobro}
                <div class="flex items-center justify-between py-3">
                  <div>
                    <p class="text-sm font-semibold text-gray-900">Cobro #{cobro.id.toString()}</p>
                    <p class="text-xs text-gray-400">{formatFecha(cobro.timestamp)}</p>
                  </div>
                  <div class="flex items-center gap-3">
                    <span class="font-bold text-gray-900">{cobro.monto.toString()} ECU</span>
                    {#if cobro.pagado}
                      <span class="text-xs font-semibold bg-green-100 text-green-700 px-3 py-1 rounded-full">Pagado</span>
                    {:else}
                      <span class="text-xs font-semibold bg-yellow-100 text-yellow-700 px-3 py-1 rounded-full">Pendiente</span>
                    {/if}
                  </div>
                </div>
                {/each}
            </div>
          {/if}
        </div>
      </div>

    {:else if seccion === 'pagar'}
      <!-- Realizar pago -->
      <div class="w-full max-w-sm mx-auto bg-white rounded-3xl shadow-xl p-8">
        <div class="flex items-center gap-2 mb-6 text-primary">
          <span class="material-symbols-outlined">qr_code_scanner</span>
          <h1 class="text-lg font-bold">Pagar un cobro</h1>
        </div>

        <label for="cobroId" class="text-sm text-gray-600 mb-1 block">Número de cobro</label>
        <div class="flex gap-2 mb-4">
          <input
            id="cobroId"
            bind:value={cobroIdBuscar}
            type="number"
            placeholder="Ej: 0"
            class="flex-1 h-12 px-4 bg-gray-50 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-primary"
          />
          <button
            on:click={buscarCobro}
            disabled={cobroIdBuscar === '' || buscandoCobro}
            class="h-12 px-4 rounded-xl bg-primary text-white font-medium disabled:opacity-50"
          >
            {#if buscandoCobro}
              <span class="material-symbols-outlined animate-spin text-[20px]">autorenew</span>
            {:else}
              Buscar
            {/if}
          </button>
        </div>

        {#if mensajePago}
          <p class="text-sm text-red-600 mb-4">{mensajePago}</p>
        {/if}

        {#if cobroEncontrado}
          <div class="bg-gray-50 rounded-2xl p-6 text-center mb-4">
            <p class="text-sm text-gray-500 mb-1">{cobroEncontrado.nombreComerciante}</p>
            <p class="text-4xl font-bold text-primary">{cobroEncontrado.monto.toString()} <span class="text-lg">ECU</span></p>
            {#if cobroEncontrado.pagado}
              <p class="text-xs text-green-600 mt-2 font-semibold">Este cobro ya fue pagado</p>
            {/if}
          </div>

          {#if !cobroEncontrado.pagado}
            <button
              on:click={pagarCobroHandler}
              disabled={pagandoCobro}
              class="w-full h-14 bg-secondary text-white font-semibold rounded-xl hover:shadow-md transition-all active:scale-[0.98] flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {#if pagandoCobro}
                <span class="material-symbols-outlined animate-spin text-[20px]">autorenew</span>
                Procesando...
              {:else}
                Pagar cobro
              {/if}
            </button>
          {/if}
        {/if}

        <button
          on:click={() => seccion = 'dashboard'}
          class="w-full h-12 mt-3 text-gray-500 text-sm hover:text-gray-700 transition-colors"
        >
          Cancelar
        </button>
      </div>

    {:else if seccion === 'pago-exitoso' && pagoExitosoInfo}
      <!-- Pago exitoso -->
      <div class="w-full max-w-sm mx-auto bg-white rounded-3xl shadow-xl p-8 flex flex-col items-center text-center">
        <div class="w-20 h-20 rounded-full bg-green-100 flex items-center justify-center mb-4">
          <span class="material-symbols-outlined text-green-600 text-[40px]">check_circle</span>
        </div>
        <h1 class="text-xl font-bold text-gray-900 mb-1">Pago exitoso</h1>
        <p class="text-gray-500 text-sm mb-6">Tu pago se ha procesado correctamente.</p>

        <div class="w-full bg-gray-50 rounded-xl p-4 mb-6 text-left space-y-2">
          <div class="flex justify-between text-sm">
            <span class="text-gray-500">Comercio</span>
            <span class="font-semibold text-gray-900">{pagoExitosoInfo.nombreComerciante}</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-gray-500">Monto</span>
            <span class="font-semibold text-gray-900">{pagoExitosoInfo.monto} ECU</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-gray-500">Cobro #</span>
            <span class="font-semibold text-gray-900">{pagoExitosoInfo.id}</span>
          </div>
        </div>

        <button
          on:click={() => seccion = 'dashboard'}
          class="w-full h-14 bg-primary text-white font-semibold rounded-xl hover:bg-primary/90 transition-colors"
        >
          Volver al inicio
        </button>
      </div>
    {/if}
  </div>
{/if}
</main>