-- Primary Direction Ecliptic Meanings
-- Tabla: primary_direction_meanings en corpus.db
--
-- Esta migración NO puebla las claves clásicas desnudas.
-- Usa el namespace ECLIPTIC_* para el modo "Longitud zodiacal
-- (informe de referencia)", de modo que el corpus clásico de
-- direcciones primarias permanezca separado.
--
-- Criterio de semáforo:
--   verde   = pasaje tradicional directo o muy cercano
--   amarillo= doctrina de apoyo, no dirección primaria exacta
--   rojo    = no integrado

INSERT INTO primary_direction_meanings (
    clave, promissor, significator, aspect,
    texto_corto, texto_largo,
    fuente_nombre, fuente_referencia,
    populated, calidad
) VALUES (
    'ECLIPTIC_ASC_VENUS_TRIGONO',
    'ASC', 'VENUS', 'TRIGONO',
    'Apertura favorable para unión, trato amable, mejoras visibles y contento corporal; lo venusino entra por puertas concretas.',
    'En longitud zodiacal, el Ascendente en trígono a Venus señala un año de composición y favor. Lilly atribuye al Ascendente dirigido a Venus contento de cuerpo y ánimo, agrado ante mujeres, ornato, casa y posibles bodas o nacimiento si la carta radical lo permite. En la práctica conviene leerlo como ventana para relaciones, mejora de imagen, acuerdos suaves y disfrute legítimo, sin prometer matrimonio si no lo sostienen otros testimonios.',
    'William Lilly, Christian Astrology (1659)',
    '[verde] Longitud zodiacal / informe de referencia. CA III, The Effects of Directions, pp. 661-662: Ascendant to body/sextile/trine Venus. Síntesis propia, no cita literal.',
    1, 8
) ON CONFLICT(clave) DO UPDATE SET
    texto_corto = excluded.texto_corto,
    texto_largo = excluded.texto_largo,
    fuente_nombre = excluded.fuente_nombre,
    fuente_referencia = excluded.fuente_referencia,
    populated = excluded.populated,
    calidad = excluded.calidad,
    updated_at = datetime('now');

INSERT INTO primary_direction_meanings (
    clave, promissor, significator, aspect,
    texto_corto, texto_largo,
    fuente_nombre, fuente_referencia,
    populated, calidad
) VALUES (
    'ECLIPTIC_SOL_MC_SEXTIL',
    'SOL', 'MC', 'SEXTIL',
    'Oportunidad moderada de visibilidad, cargo, encargo público o favor de superiores.',
    'Esta clave del informe por longitud zodiacal une el Sol, significador de honra, autoridad y estimación, con el Medio Cielo, lugar de oficio y reputación. El apoyo tradicional es indirecto: Lilly describe el buen aspecto del MC al Sol como promesa de oficios, honores y amistad de personas eminentes. Por tanto se integra como indicio amarillo de promoción, reconocimiento o encargo visible, condicionado por la fortaleza radical del Sol y del MC.',
    'William Lilly, Christian Astrology (1659)',
    '[amarillo] Longitud zodiacal / informe de referencia. CA III, The Effects of Directions, p. 672: MC to sextile/trine Sun; apoyo por inversión de la relación Sol-MC, no cita directa de Sol dirigido al MC.',
    1, 6
) ON CONFLICT(clave) DO UPDATE SET
    texto_corto = excluded.texto_corto,
    texto_largo = excluded.texto_largo,
    fuente_nombre = excluded.fuente_nombre,
    fuente_referencia = excluded.fuente_referencia,
    populated = excluded.populated,
    calidad = excluded.calidad,
    updated_at = datetime('now');

INSERT INTO primary_direction_meanings (
    clave, promissor, significator, aspect,
    texto_corto, texto_largo,
    fuente_nombre, fuente_referencia,
    populated, calidad
) VALUES (
    'ECLIPTIC_MC_LUNA_SEXTIL',
    'MC', 'LUNA', 'SEXTIL',
    'Aumento de reputación ante el público y movimiento beneficioso en oficio, encargos o trato con mujeres.',
    'El MC dirigido por buen aspecto a la Luna, según Lilly, incrementa fortuna, estimación y honra de parte del pueblo, con posibles dones de una mujer principal y prosperidad en oficios o mandos. En lectura por longitud zodiacal conserva ese tono: una ocasión pública que se mueve por audiencia, clientela, comunidad, viajes o figura femenina. La Luna no da permanencia por sí sola; pide atender a cambios de ánimo colectivo y a la condición radical lunar.',
    'William Lilly, Christian Astrology (1659)',
    '[verde] Longitud zodiacal / informe de referencia. CA III, The Effects of Directions, p. 676: MC to sextile/trine Moon. Síntesis propia, no cita literal.',
    1, 8
) ON CONFLICT(clave) DO UPDATE SET
    texto_corto = excluded.texto_corto,
    texto_largo = excluded.texto_largo,
    fuente_nombre = excluded.fuente_nombre,
    fuente_referencia = excluded.fuente_referencia,
    populated = excluded.populated,
    calidad = excluded.calidad,
    updated_at = datetime('now');

INSERT INTO primary_direction_meanings (
    clave, promissor, significator, aspect,
    texto_corto, texto_largo,
    fuente_nombre, fuente_referencia,
    populated, calidad
) VALUES (
    'ECLIPTIC_LUNA_VENUS_TRIGONO',
    'LUNA', 'VENUS', 'TRIGONO',
    'Tiempo fértil y agradable para acuerdos, matrimonio, casa, trato femenino y aumento sereno de bienes.',
    'Lilly considera el buen aspecto de la Luna a Venus uno de los más placenteros: éxito en asuntos, matrimonio feliz si corresponde, concordia familiar y buena disposición del cuerpo. Esta dirección por longitud zodiacal se lee como suavización de conflictos y apertura a alianzas, gozos lícitos, arreglo doméstico y favor de mujeres o personas venusinas. Si Venus está debilitada radicalmente, el bien puede quedar en placer pasajero o gasto decoroso más que en logro duradero.',
    'William Lilly, Christian Astrology (1659)',
    '[verde] Longitud zodiacal / informe de referencia. CA III, The Effects of Directions, pp. 697-698: Moon to sextile/trine Venus. Síntesis propia, no cita literal.',
    1, 8
) ON CONFLICT(clave) DO UPDATE SET
    texto_corto = excluded.texto_corto,
    texto_largo = excluded.texto_largo,
    fuente_nombre = excluded.fuente_nombre,
    fuente_referencia = excluded.fuente_referencia,
    populated = excluded.populated,
    calidad = excluded.calidad,
    updated_at = datetime('now');

INSERT INTO primary_direction_meanings (
    clave, promissor, significator, aspect,
    texto_corto, texto_largo,
    fuente_nombre, fuente_referencia,
    populated, calidad
) VALUES (
    'ECLIPTIC_SATURNO_MC_TRIGONO',
    'SATURNO', 'MC', 'TRIGONO',
    'Consolidación sobria de oficio y reputación mediante mayores, instituciones, tierras o responsabilidades pesadas.',
    'Lilly da al buen aspecto del MC con Saturno honra o estima por personas ancianas o saturninas, mayor gravedad, trato con tierras, casas, huertos, madera y asuntos de gobierno local. En longitud zodiacal no debe venderse como elevación fácil: Saturno concede por duración, carga y oficio, no por aplauso rápido. Si el radix lo permite, el periodo favorece madurar una posición, asumir mando sobrio, ordenar patrimonio profesional y ganar respeto por constancia.',
    'William Lilly, Christian Astrology (1659)',
    '[amarillo] Longitud zodiacal / informe de referencia. CA III, The Effects of Directions, p. 669: MC to sextile/trine Saturn; apoyo cercano aplicado a Saturno dirigido al MC, no cita directa de esta variante.',
    1, 7
) ON CONFLICT(clave) DO UPDATE SET
    texto_corto = excluded.texto_corto,
    texto_largo = excluded.texto_largo,
    fuente_nombre = excluded.fuente_nombre,
    fuente_referencia = excluded.fuente_referencia,
    populated = excluded.populated,
    calidad = excluded.calidad,
    updated_at = datetime('now');

INSERT INTO primary_direction_meanings (
    clave, promissor, significator, aspect,
    texto_corto, texto_largo,
    fuente_nombre, fuente_referencia,
    populated, calidad
) VALUES (
    'ECLIPTIC_MC_DSC_TRIGONO',
    'MC', 'DSC', 'TRIGONO',
    'Relaciones, pactos o contraparte pública entran en el centro de la reputación y pueden abrir acuerdos visibles.',
    'No hay aquí una correspondencia clásica directa de dirección primaria antigua; se integra como lectura amarilla del informe por longitud zodiacal. La base doctrinal es la unión entre el MC, casa de honras, oficio y magistrados, y el Descendente o casa VII, lugar de matrimonio, socios, rivales abiertos y contratos; el trígono es de amistad perfecta en la doctrina de aspectos. El periodo puede traer pareja o alianza a la escena pública, pacto profesional, mediación ante una contraparte o definición de vínculo con efecto visible.',
    'Henry Coley, Clavis Astrologiae Elimata (1676)',
    '[amarillo] Longitud zodiacal / informe de referencia. Clavis, pp. 33-34 sobre aspectos y pp. 119-120 sobre casas VII y X; apoyo doctrinal, no dirección primaria clásica directa.',
    1, 6
) ON CONFLICT(clave) DO UPDATE SET
    texto_corto = excluded.texto_corto,
    texto_largo = excluded.texto_largo,
    fuente_nombre = excluded.fuente_nombre,
    fuente_referencia = excluded.fuente_referencia,
    populated = excluded.populated,
    calidad = excluded.calidad,
    updated_at = datetime('now');

INSERT INTO primary_direction_meanings (
    clave, promissor, significator, aspect,
    texto_corto, texto_largo,
    fuente_nombre, fuente_referencia,
    populated, calidad
) VALUES (
    'ECLIPTIC_SATURNO_ASC_TRIGONO',
    'SATURNO', 'ASC', 'TRIGONO',
    'Maduración del cuerpo y del rumbo vital: sobriedad, orden, tierras, obligaciones y trato con mayores.',
    'El apoyo clásico procede del Ascendente dirigido al buen aspecto de Saturno: Lilly habla de mayor gravedad, sobriedad, trato con hombres antiguos, reputación más que lucro y provecho en tierras, casas o labores rurales. Como clave de longitud zodiacal con Saturno dirigido al Ascendente, debe leerse como consolidación austera de la vida y del cuerpo, con deberes que pesan pero ordenan. Si Saturno está mal dispuesto, el bien se vuelve lento y seco; si está fuerte, da firmeza y criterio.',
    'William Lilly, Christian Astrology (1659)',
    '[amarillo] Verificación histórica; Longitud zodiacal / informe de referencia. CA III, The Effects of Directions, pp. 656-657: Ascendant to sextile/trine Saturn; apoyo cercano aplicado a Saturno dirigido al ASC.',
    1, 7
) ON CONFLICT(clave) DO UPDATE SET
    texto_corto = excluded.texto_corto,
    texto_largo = excluded.texto_largo,
    fuente_nombre = excluded.fuente_nombre,
    fuente_referencia = excluded.fuente_referencia,
    populated = excluded.populated,
    calidad = excluded.calidad,
    updated_at = datetime('now');

INSERT INTO primary_direction_meanings (
    clave, promissor, significator, aspect,
    texto_corto, texto_largo,
    fuente_nombre, fuente_referencia,
    populated, calidad
) VALUES (
    'ECLIPTIC_ASC_SOL_CUADRATURA',
    'ASC', 'SOL', 'CUADRATURA',
    'Prueba de visibilidad y mando: roces con autoridad, gasto de fuerzas y posible daño de estimación si se actúa con orgullo.',
    'El Ascendente en cuadratura al Sol es una dirección de tensión sobre cuerpo, honra y relación con superiores. Lilly vincula el mal aspecto del Ascendente al Sol con disgusto de príncipes o magistrados, pérdidas, contiendas, ojos dolientes y año de litigio o contradicción. En longitud zodiacal conviene leerla como examen público de la voluntad: se gana prudencia si se evita la soberbia, la exposición innecesaria y el choque frontal con figuras de mando.',
    'William Lilly, Christian Astrology (1659)',
    '[verde] Verificación histórica; Longitud zodiacal / informe de referencia. CA III, The Effects of Directions, p. 661: Ascendant to square/opposition Sun. Síntesis propia, no cita literal.',
    1, 8
) ON CONFLICT(clave) DO UPDATE SET
    texto_corto = excluded.texto_corto,
    texto_largo = excluded.texto_largo,
    fuente_nombre = excluded.fuente_nombre,
    fuente_referencia = excluded.fuente_referencia,
    populated = excluded.populated,
    calidad = excluded.calidad,
    updated_at = datetime('now');
