// Avisos de alertas nuevas: sonido, notificación del sistema y título de la pestaña que parpadea.
// Así el guardia se entera aunque esté mirando otra ventana (por ejemplo, el monitor de las cámaras).
//
// zentry.js consulta el estado cada 3 segundos y lanza el evento "zentry:estado" con los datos;
// aquí solo escuchamos ese evento y miramos si llegaron alertas nuevas.

(function () {
  const boton = document.getElementById('boton-avisos');
  if (!boton) return; // páginas sin campana (por ejemplo, el inicio de sesión)

  const sonido = new Audio(boton.dataset.sonido);
  const tituloOriginal = document.title;
  let alertasSinVer = 0;
  let parpadeo = null;

  // Los avisos quedan encendidos o apagados en este navegador (localStorage).
  function avisosActivos() {
    try {
      return localStorage.getItem('zentry-avisos') === 'si';
    } catch (error) {
      return false; // navegador en modo privado o sin almacenamiento
    }
  }

  function guardarPreferencia(activos) {
    try {
      localStorage.setItem('zentry-avisos', activos ? 'si' : 'no');
    } catch (error) {
      // no pasa nada: solo no se recordará al recargar
    }
    // zentry.js lee esto para seguir consultando cada 3 s aunque la pestaña esté en segundo plano
    document.body.dataset.avisos = activos ? 'si' : 'no';
  }

  function pintarBoton() {
    const activos = avisosActivos();
    boton.setAttribute('aria-pressed', activos ? 'true' : 'false');
    boton.title = activos ? 'Avisos con sonido activos (clic para silenciar)' : 'Activar avisos con sonido';
    boton.innerHTML = Zentry.icono(activos ? 'volume-2' : 'volume-x', 20);
  }

  function sonar() {
    sonido.currentTime = 0;
    // El navegador bloquea el sonido hasta que la persona hace clic en la página al menos una vez
    sonido.play().catch(function () {});
  }

  function mostrarNotificacion(alerta) {
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    const notificacion = new Notification('Zentry · ' + alerta.texto, {
      body: alerta.placa + ' · ' + alerta.resultado_texto,
      tag: 'zentry-alerta-' + alerta.alerta_id, // si llega dos veces, no se repite
      icon: boton.dataset.icono,
      requireInteraction: true, // se queda en pantalla hasta que alguien la mire
    });
    notificacion.onclick = function () {
      window.focus();
      window.location.href = Zentry.urlAlerta(alerta.alerta_id);
      notificacion.close();
    };
  }

  function estaMirandoLaPagina() {
    return document.visibilityState === 'visible' && document.hasFocus();
  }

  function parpadearTitulo() {
    if (parpadeo) return; // ya está parpadeando
    let mostrarAviso = true;
    parpadeo = setInterval(function () {
      document.title = mostrarAviso ? '(' + alertasSinVer + ') ⚠ Nueva alerta' : tituloOriginal;
      mostrarAviso = !mostrarAviso;
    }, 1000);
  }

  function dejarDeParpadear() {
    clearInterval(parpadeo);
    parpadeo = null;
    alertasSinVer = 0;
    document.title = tituloOriginal;
  }

  // Cada vez que llega el estado, revisamos las alertas nuevas
  document.addEventListener('zentry:estado', function (evento) {
    const nuevas = evento.detail.avisos.filter(function (aviso) {
      return aviso.tipo === 'creada';
    });
    if (nuevas.length === 0) return;

    // El título parpadea siempre que la persona no esté mirando la página
    if (!estaMirandoLaPagina()) {
      alertasSinVer += nuevas.length;
      parpadearTitulo();
    }

    if (!avisosActivos()) return;

    // Suena solo con las alertas graves (discrepancia y placa no registrada)
    const hayGraves = nuevas.some(function (aviso) {
      return aviso.resultado === 'discrepancia' || aviso.resultado === 'no_registrada';
    });
    if (hayGraves) sonar();

    // La notificación del sistema solo hace falta si la página no está a la vista
    if (!estaMirandoLaPagina()) nuevas.forEach(mostrarNotificacion);
  });

  // Botón para encender o apagar los avisos
  boton.addEventListener('click', async function () {
    if (avisosActivos()) {
      guardarPreferencia(false);
      pintarBoton();
      Zentry.aviso('Avisos con sonido desactivados');
      return;
    }

    // Pedir permiso para las notificaciones (el navegador muestra su propia pregunta)
    if ('Notification' in window && Notification.permission === 'default') {
      await Notification.requestPermission();
    }
    guardarPreferencia(true);
    pintarBoton();
    sonar(); // prueba: así la persona escucha cómo suena

    if ('Notification' in window && Notification.permission === 'granted') {
      Zentry.aviso('Avisos activos: sonará y saldrá una notificación aunque estés en otra ventana');
    } else {
      Zentry.aviso('Avisos con sonido activos. Las notificaciones están bloqueadas en este navegador');
    }
  });

  // Al volver a la pestaña, el título deja de parpadear
  window.addEventListener('focus', dejarDeParpadear);
  document.addEventListener('visibilitychange', function () {
    if (estaMirandoLaPagina()) dejarDeParpadear();
  });

  guardarPreferencia(avisosActivos());
  pintarBoton();
})();
