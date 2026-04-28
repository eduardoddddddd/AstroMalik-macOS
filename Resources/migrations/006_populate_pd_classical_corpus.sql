-- Migración 006: Corpus completo de Direcciones Primarias clásicas
-- Generado: 2026-04-28
-- Método: síntesis propia en español a partir de pasajes localizados de Lilly,
--   Christian Astrology (1647), Libro III, sección The Effects of Directions.
-- Fuente principal: /Users/eduardoariasbravo/Developer/horaria/fuentes/lilly_christian_astrology_completo.txt
-- Fuente complementaria revisada: corpus_sources/text/coley_clavis_skyscript.txt
--   Coley confirma doctrina general de direcciones y remite a tradición/líneas afines;
--   no se usa para marcar verdes cuando Lilly ya aporta pasaje concreto.
-- Política de honestidad: verde = pasaje concreto localizable; amarillo = síntesis doctrinal;
--   rojo = sin fuente disponible, populated=0. Esta migración contiene 165 verdes.
-- No toca entradas ECLIPTIC_*.


INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_ASC_CONJUNCION',
  'SOL',
  'ASC',
  'CONJUNCION',
  'Contacto directo del Sol sobre ASC: dignidad o empleo visible, ansiedad, secretos publicados, cabeza y ojos sensibles. Se nota de forma directa.',
  'Lilly asocia el Ascendente dirigido al cuerpo del Sol con oficio o favor de autoridades, aceptación pública, exposición de asuntos ocultos, gasto, discordia con hermanos y dolencias de cabeza u ojos según el signo. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.694-695. Líneas ~29435-29453 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_ASC_SEXTIL',
  'SOL',
  'ASC',
  'SEXTIL',
  'Oportunidad moderada del Sol sobre ASC: salud, tranquilidad, reputación, amigos eminentes, viajes honrosos y empleo útil. Requiere cooperación consciente.',
  'Lilly asocia el Ascendente dirigido al sextil del Sol con salud corporal, serenidad mental, aumento de bienes y estima, amistades de cuenta, viajes o encargos honorables y provechosos. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.695. Líneas ~29454-29459 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_ASC_CUADRATURA',
  'SOL',
  'ASC',
  'CUADRATURA',
  'Tensión activa del Sol sobre ASC: desfavor de superiores, pérdidas, pleitos, ojos dañados y enfermedades coléricas. Pide actuar ante la fricción.',
  'Lilly asocia el Ascendente dirigido a la cuadratura del Sol con descontento de magistrados o nobles, peligro para el padre, pérdidas, engaños, decadencia de estado, contiendas legales y mayor severidad en oposición. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.695. Líneas ~29460-29472 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_ASC_TRIGONO',
  'SOL',
  'ASC',
  'TRIGONO',
  'Flujo favorable del Sol sobre ASC: salud, tranquilidad, reputación, amigos eminentes, viajes honrosos y empleo útil. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Ascendente dirigido al trígono del Sol con salud corporal, serenidad mental, aumento de bienes y estima, amistades de cuenta, viajes o encargos honorables y provechosos. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.695. Líneas ~29454-29459 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_ASC_OPOSICION',
  'SOL',
  'ASC',
  'OPOSICION',
  'Confrontación externa del Sol sobre ASC: desfavor de superiores, pérdidas, pleitos, ojos dañados y enfermedades coléricas. Se manifiesta frente a otros.',
  'Lilly asocia el Ascendente dirigido a la oposición del Sol con descontento de magistrados o nobles, peligro para el padre, pérdidas, engaños, decadencia de estado, contiendas legales y mayor severidad en oposición. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.695. Líneas ~29460-29472 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_ASC_CONJUNCION',
  'LUNA',
  'ASC',
  'CONJUNCION',
  'Contacto directo de la Luna sobre ASC: cambio rápido en salud, negocios, viajes, matrimonio o fortuna según la Luna natal. Se nota de forma directa.',
  'Lilly asocia el Ascendente dirigido al cuerpo de la Luna con prosperidad o empobrecimiento repentino, accidentes cerca del agua, cólicos y males lunares si está débil; salud, viaje o matrimonio si está fuerte. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.697-698. Líneas ~29573-29595 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_ASC_SEXTIL',
  'LUNA',
  'ASC',
  'SEXTIL',
  'Oportunidad moderada de la Luna sobre ASC: ocupación abundante, salud, ánimo contento, favor de mujeres, madre y vecinos. Requiere cooperación consciente.',
  'Lilly asocia el Ascendente dirigido al sextil de la Luna con mucha actividad con satisfacción, buen estado corporal, afecto de mujeres jóvenes, asuntos de madre y parientes favorecidos, estima vecinal y posible hija. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.698. Líneas ~29596-29603 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_ASC_CUADRATURA',
  'LUNA',
  'ASC',
  'CUADRATURA',
  'Tensión activa de la Luna sobre ASC: discordias con madre, esposa o mujeres, humores corruptos, agua, ojos y pérdida de favor. Pide actuar ante la fricción.',
  'Lilly asocia el Ascendente dirigido a la cuadratura de la Luna con celos, afrentas de gente ruda, daño de mujeres comunes, peligro por agua, molestias del ojo izquierdo, viajes fallidos y desorden de dieta. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.698. Líneas ~29604-29616 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_ASC_TRIGONO',
  'LUNA',
  'ASC',
  'TRIGONO',
  'Flujo favorable de la Luna sobre ASC: ocupación abundante, salud, ánimo contento, favor de mujeres, madre y vecinos. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Ascendente dirigido al trígono de la Luna con mucha actividad con satisfacción, buen estado corporal, afecto de mujeres jóvenes, asuntos de madre y parientes favorecidos, estima vecinal y posible hija. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.698. Líneas ~29596-29603 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_ASC_OPOSICION',
  'LUNA',
  'ASC',
  'OPOSICION',
  'Confrontación externa de la Luna sobre ASC: discordias con madre, esposa o mujeres, humores corruptos, agua, ojos y pérdida de favor. Se manifiesta frente a otros.',
  'Lilly asocia el Ascendente dirigido a la oposición de la Luna con celos, afrentas de gente ruda, daño de mujeres comunes, peligro por agua, molestias del ojo izquierdo, viajes fallidos y desorden de dieta. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.698. Líneas ~29604-29616 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_ASC_CONJUNCION',
  'MERCURIO',
  'ASC',
  'CONJUNCION',
  'Contacto directo de Mercurio sobre ASC: estudio, letras, comercio, cuentas, viajes, oficio útil y trato con escribanos. Se nota de forma directa.',
  'Lilly asocia el Ascendente dirigido al cuerpo de Mercurio con poesía, matemáticas, letras, ganancia por oficio, comercio, profesión o manufactura, viajes y ocupación con leyes, cuentas y abogados. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.696-697. Líneas ~29523-29541 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_ASC_SEXTIL',
  'MERCURIO',
  'ASC',
  'SEXTIL',
  'Oportunidad moderada de Mercurio sobre ASC: entendimiento agudo, aprendizaje, contratos, viajes, mensajes y provecho por escritura. Requiere cooperación consciente.',
  'Lilly asocia el Ascendente dirigido al sextil de Mercurio con impulso a la literatura, universidad, negociaciones, contratos, mensajerías y empleos de confianza con cuentas, pluma o mayordomía. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.697. Líneas ~29542-29555 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_ASC_CUADRATURA',
  'MERCURIO',
  'ASC',
  'CUADRATURA',
  'Tensión activa de Mercurio sobre ASC: estudios inútiles, pleitos, fraudes, criados malos, deudas ajenas y escritos dañinos. Pide actuar ante la fricción.',
  'Lilly asocia el Ascendente dirigido a la cuadratura de Mercurio con gasto vano por aprender, abandono de estudios, problemas respiratorios o cutáneos, conspiraciones reveladas, fraudes contractuales, embargos y falsos testimonios. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.697. Líneas ~29556-29568 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_ASC_TRIGONO',
  'MERCURIO',
  'ASC',
  'TRIGONO',
  'Flujo favorable de Mercurio sobre ASC: entendimiento agudo, aprendizaje, contratos, viajes, mensajes y provecho por escritura. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Ascendente dirigido al trígono de Mercurio con impulso a la literatura, universidad, negociaciones, contratos, mensajerías y empleos de confianza con cuentas, pluma o mayordomía. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.697. Líneas ~29542-29555 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_ASC_OPOSICION',
  'MERCURIO',
  'ASC',
  'OPOSICION',
  'Confrontación externa de Mercurio sobre ASC: estudios inútiles, pleitos, fraudes, criados malos, deudas ajenas y escritos dañinos. Se manifiesta frente a otros.',
  'Lilly asocia el Ascendente dirigido a la oposición de Mercurio con gasto vano por aprender, abandono de estudios, problemas respiratorios o cutáneos, conspiraciones reveladas, fraudes contractuales, embargos y falsos testimonios. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.697. Líneas ~29556-29568 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_ASC_CONJUNCION',
  'VENUS',
  'ASC',
  'CONJUNCION',
  'Contacto directo de Venus sobre ASC: placer, trato femenino, adornos, casa, matrimonio o hijo, con riesgo de exceso sensual. Se nota de forma directa.',
  'Lilly asocia el Ascendente dirigido al cuerpo de Venus con contento de cuerpo y mente, aceptación de mujeres, galantería, ropa, joyas, útiles domésticos, boda o nacimiento si la edad lo permite. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.695-696. Líneas ~29474-29498 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_ASC_SEXTIL',
  'VENUS',
  'ASC',
  'SEXTIL',
  'Oportunidad moderada de Venus sobre ASC: tiempo grato y provechoso, banquetes, afectos, éxito laboral y buen trato familiar. Requiere cooperación consciente.',
  'Lilly asocia el Ascendente dirigido al sextil de Venus con alegría, compañía de mujeres, matrimonio o hijo, provecho en oficio o granja, bondad de parientes y respeto social. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.696. Líneas ~29499-29506 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_ASC_CUADRATURA',
  'VENUS',
  'ASC',
  'CUADRATURA',
  'Tensión activa de Venus sobre ASC: incomodidad por placeres, desorden amoroso, celos, mujeres adversas y descrédito. Pide actuar ante la fricción.',
  'Lilly asocia el Ascendente dirigido a la cuadratura de Venus con enfermedad por exceso, venéreo o sensual, adulterio, sospecha pública, riñas por celos, rechazo de mujeres honestas y gasto por placer. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.696. Líneas ~29507-29517 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_ASC_TRIGONO',
  'VENUS',
  'ASC',
  'TRIGONO',
  'Flujo favorable de Venus sobre ASC: tiempo grato y provechoso, banquetes, afectos, éxito laboral y buen trato familiar. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Ascendente dirigido al trígono de Venus con alegría, compañía de mujeres, matrimonio o hijo, provecho en oficio o granja, bondad de parientes y respeto social. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.696. Líneas ~29499-29506 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_ASC_OPOSICION',
  'VENUS',
  'ASC',
  'OPOSICION',
  'Confrontación externa de Venus sobre ASC: incomodidad por placeres, desorden amoroso, celos, mujeres adversas y descrédito. Se manifiesta frente a otros.',
  'Lilly asocia el Ascendente dirigido a la oposición de Venus con enfermedad por exceso, venéreo o sensual, adulterio, sospecha pública, riñas por celos, rechazo de mujeres honestas y gasto por placer. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.696. Líneas ~29507-29517 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_ASC_CONJUNCION',
  'MARTE',
  'ASC',
  'CONJUNCION',
  'Contacto directo de Marte sobre ASC: cólera, disputas, heridas, fiebre, prisión o peligros por hierro, fuego y viajes. Se nota de forma directa.',
  'Lilly asocia el Ascendente dirigido al cuerpo de Marte con impetuosidad, pleitos, duelos, enemigos, daño por caballos, armas, fuego o disparos, fiebre violenta, viruela o peste según el contexto. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.693. Líneas ~29372-29388 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_ASC_SEXTIL',
  'MARTE',
  'ASC',
  'SEXTIL',
  'Oportunidad moderada de Marte sobre ASC: energía marcial, ejercicios, mando, inventiva técnica y contacto con soldados. Requiere cooperación consciente.',
  'Lilly asocia el Ascendente dirigido al sextil de Marte con inclinación a armas, equitación, estrategia y oficios mecánicos; da respeto de soldados o comandantes y actividad intensa, aunque con gasto. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.693. Líneas ~29389-29398 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_ASC_CUADRATURA',
  'MARTE',
  'ASC',
  'CUADRATURA',
  'Tensión activa de Marte sobre ASC: fiebre aguda, accidentes, heridas, enemigos, acusaciones y gastos fuertes. Pide actuar ante la fricción.',
  'Lilly asocia el Ascendente dirigido a la cuadratura de Marte con sobrecalentamiento de la sangre, caídas, quemaduras, conflictos, denuncias, inflamaciones, peligro por mar o tierra según signo y mitigación de fortunas. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.694. Líneas ~29404-29428 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_ASC_TRIGONO',
  'MARTE',
  'ASC',
  'TRIGONO',
  'Flujo favorable de Marte sobre ASC: energía marcial, ejercicios, mando, inventiva técnica y contacto con soldados. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Ascendente dirigido al trígono de Marte con inclinación a armas, equitación, estrategia y oficios mecánicos; da respeto de soldados o comandantes y actividad intensa, aunque con gasto. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.693. Líneas ~29389-29398 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_ASC_OPOSICION',
  'MARTE',
  'ASC',
  'OPOSICION',
  'Confrontación externa de Marte sobre ASC: fiebre aguda, accidentes, heridas, enemigos, acusaciones y gastos fuertes. Se manifiesta frente a otros.',
  'Lilly asocia el Ascendente dirigido a la oposición de Marte con sobrecalentamiento de la sangre, caídas, quemaduras, conflictos, denuncias, inflamaciones, peligro por mar o tierra según signo y mitigación de fortunas. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.694. Líneas ~29404-29428 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_ASC_CONJUNCION',
  'JUPITER',
  'ASC',
  'CONJUNCION',
  'Contacto directo de Júpiter sobre ASC: salud, alegría, patronazgo, crédito, prosperidad y posible matrimonio o grado. Se nota de forma directa.',
  'Lilly asocia el Ascendente dirigido al cuerpo de Júpiter con constitución sana, ánimo afable y religioso, favor de personas eminentes, aumento de crédito, bienes inesperados, hijos o beneficios joviales. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.691-692. Líneas ~29299-29330 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_ASC_SEXTIL',
  'JUPITER',
  'ASC',
  'SEXTIL',
  'Oportunidad moderada de Júpiter sobre ASC: aumento de fortuna, honor, amistades, viajes útiles y favor de nobles o clérigos. Requiere cooperación consciente.',
  'Lilly asocia el Ascendente dirigido al sextil de Júpiter con incremento de patrimonio, amistad y gloria, tranquilidad de mente y cuerpo, embajadas o viajes provechosos, comercio abundante y cosechas fértiles. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.692. Líneas ~29331-29345 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_ASC_CUADRATURA',
  'JUPITER',
  'ASC',
  'CUADRATURA',
  'Tensión activa de Júpiter sobre ASC: enemistades con juristas, clérigos o nobles, engaños, gastos y desorden vital. Pide actuar ante la fricción.',
  'Lilly asocia el Ascendente dirigido a la cuadratura de Júpiter con controversias con abogados, religiosos o caballeros, traiciones bajo apariencia amistosa, intemperancia, daño por fianzas y disputas doctrinales. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.692-693. Líneas ~29346-29367 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_ASC_TRIGONO',
  'JUPITER',
  'ASC',
  'TRIGONO',
  'Flujo favorable de Júpiter sobre ASC: aumento de fortuna, honor, amistades, viajes útiles y favor de nobles o clérigos. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Ascendente dirigido al trígono de Júpiter con incremento de patrimonio, amistad y gloria, tranquilidad de mente y cuerpo, embajadas o viajes provechosos, comercio abundante y cosechas fértiles. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.692. Líneas ~29331-29345 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_ASC_OPOSICION',
  'JUPITER',
  'ASC',
  'OPOSICION',
  'Confrontación externa de Júpiter sobre ASC: enemistades con juristas, clérigos o nobles, engaños, gastos y desorden vital. Se manifiesta frente a otros.',
  'Lilly asocia el Ascendente dirigido a la oposición de Júpiter con controversias con abogados, religiosos o caballeros, traiciones bajo apariencia amistosa, intemperancia, daño por fianzas y disputas doctrinales. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLIX, p.692-693. Líneas ~29346-29367 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_ASC_CONJUNCION',
  'SATURNO',
  'ASC',
  'CONJUNCION',
  'Contacto directo de Saturno sobre ASC: dolencias frías, abatimiento, lentitud y peligro por agua o lugares húmedos. Se nota de forma directa.',
  'Lilly asocia el Ascendente dirigido al cuerpo de Saturno con mala disposición corporal, enfermedades largas de frío o flema, tos, vértigos, fantasías sombrías, consunción y torpeza anímica. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLVIII, p.690. Líneas ~29238-29251 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_ASC_SEXTIL',
  'SATURNO',
  'ASC',
  'SEXTIL',
  'Oportunidad moderada de Saturno sobre ASC: trato útil con mayores, sobriedad, labores de tierra, edificios, legados y bienes estables. Requiere cooperación consciente.',
  'Lilly asocia el Ascendente dirigido al sextil de Saturno con gravedad, prudencia, relación con personas antiguas, beneficios por tierras, arrendamientos, minas, edificios, granjas o bienes saturninos. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLVIII, p.690-691. Líneas ~29252-29276 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_ASC_CUADRATURA',
  'SATURNO',
  'ASC',
  'CUADRATURA',
  'Tensión activa de Saturno sobre ASC: año pesado de enfermedad crónica, retrasos, pérdida de oficio, reputación o ánimo. Pide actuar ante la fricción.',
  'Lilly asocia el Ascendente dirigido a la cuadratura de Saturno con peligro si otros testimonios ayudan, males fríos y secos, retorno de dolencias, cólicos, gota, fístulas, tumores, tristeza y descrédito. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLVIII, p.691. Líneas ~29277-29288 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_ASC_TRIGONO',
  'SATURNO',
  'ASC',
  'TRIGONO',
  'Flujo favorable de Saturno sobre ASC: trato útil con mayores, sobriedad, labores de tierra, edificios, legados y bienes estables. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Ascendente dirigido al trígono de Saturno con gravedad, prudencia, relación con personas antiguas, beneficios por tierras, arrendamientos, minas, edificios, granjas o bienes saturninos. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLVIII, p.690-691. Líneas ~29252-29276 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_ASC_OPOSICION',
  'SATURNO',
  'ASC',
  'OPOSICION',
  'Confrontación externa de Saturno sobre ASC: año pesado de enfermedad crónica, retrasos, pérdida de oficio, reputación o ánimo. Se manifiesta frente a otros.',
  'Lilly asocia el Ascendente dirigido a la oposición de Saturno con peligro si otros testimonios ayudan, males fríos y secos, retorno de dolencias, cólicos, gota, fístulas, tumores, tristeza y descrédito. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLVIII, p.691. Líneas ~29277-29288 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_MC_CONJUNCION',
  'SOL',
  'MC',
  'CONJUNCION',
  'Contacto directo del Sol sobre MC: dignidad pública, favor de reyes o nobles, fama y aceptación de autoridades. Se nota de forma directa.',
  'Lilly asocia el Medio Cielo dirigido al cuerpo del Sol con elevación al honor, hace conocido, da confianza de personas principales, buena gestión de negocios ajenos, favor público y prosperidad de padres si viven. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.706. Líneas ~29896-29909 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_MC_SEXTIL',
  'SOL',
  'MC',
  'SEXTIL',
  'Oportunidad moderada del Sol sobre MC: oficios, honores, dones y amistad de poderosos con reputación amplia. Requiere cooperación consciente.',
  'Lilly asocia el Medio Cielo dirigido al sextil del Sol con promesa de cargos, regalos y apoyo de reyes o nobles, magnanimidad, gobierno con elogio y afecto popular en cartas principescas. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.706. Líneas ~29910-29921 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_MC_CUADRATURA',
  'SOL',
  'MC',
  'CUADRATURA',
  'Tensión activa del Sol sobre MC: odio de grandes hombres, pérdida súbita de honores, quiebra, prisión o exilio. Pide actuar ante la fricción.',
  'Lilly asocia el Medio Cielo dirigido a la cuadratura del Sol con discomodidades, caída de oficios y preferencias, reversión de fortuna, daño a padres, condena si la carta lo indica y pérdida de amor de nobles. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.706-707. Líneas ~29922-29968 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_MC_TRIGONO',
  'SOL',
  'MC',
  'TRIGONO',
  'Flujo favorable del Sol sobre MC: oficios, honores, dones y amistad de poderosos con reputación amplia. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Medio Cielo dirigido al trígono del Sol con promesa de cargos, regalos y apoyo de reyes o nobles, magnanimidad, gobierno con elogio y afecto popular en cartas principescas. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.706. Líneas ~29910-29921 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_MC_OPOSICION',
  'SOL',
  'MC',
  'OPOSICION',
  'Confrontación externa del Sol sobre MC: odio de grandes hombres, pérdida súbita de honores, quiebra, prisión o exilio. Se manifiesta frente a otros.',
  'Lilly asocia el Medio Cielo dirigido a la oposición del Sol con discomodidades, caída de oficios y preferencias, reversión de fortuna, daño a padres, condena si la carta lo indica y pérdida de amor de nobles. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.706-707. Líneas ~29922-29968 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_MC_CONJUNCION',
  'LUNA',
  'MC',
  'CONJUNCION',
  'Contacto directo de la Luna sobre MC: ocupación pública variable, viajes, matrimonio, comercio o preferencia según Luna natal. Se nota de forma directa.',
  'Lilly asocia el Medio Cielo dirigido al cuerpo de la Luna con tiempo inquieto con ganancias y pérdidas; si la Luna está dignificada trae comercio, oficio, dignidad, exposición pública y amistad femenina. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.709-710. Líneas ~30069-30081 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_MC_SEXTIL',
  'LUNA',
  'MC',
  'SEXTIL',
  'Oportunidad moderada de la Luna sobre MC: estima del pueblo, dones de dama noble, oficio próspero, viaje y matrimonio. Requiere cooperación consciente.',
  'Lilly asocia el Medio Cielo dirigido al sextil de la Luna con aumento de fortuna, honor popular, apoyo femenino, éxito en cargos, matrimonio conforme a la condición lunar y posible viaje marítimo. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.710. Líneas ~30082-30091 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_MC_CUADRATURA',
  'LUNA',
  'MC',
  'CUADRATURA',
  'Tensión activa de la Luna sobre MC: desestima popular, conflictos con mujeres, pérdida de estado, gasto vano y riesgo para madre o esposa. Pide actuar ante la fricción.',
  'Lilly asocia el Medio Cielo dirigido a la cuadratura de la Luna con contrariedades por mujeres, pérdida de honor y dignidad, despilfarro, muerte o peligro de madre/esposa, sentencia de magistrado y duración según signo. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.710. Líneas ~30092-30104 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_MC_TRIGONO',
  'LUNA',
  'MC',
  'TRIGONO',
  'Flujo favorable de la Luna sobre MC: estima del pueblo, dones de dama noble, oficio próspero, viaje y matrimonio. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Medio Cielo dirigido al trígono de la Luna con aumento de fortuna, honor popular, apoyo femenino, éxito en cargos, matrimonio conforme a la condición lunar y posible viaje marítimo. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.710. Líneas ~30082-30091 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_MC_OPOSICION',
  'LUNA',
  'MC',
  'OPOSICION',
  'Confrontación externa de la Luna sobre MC: desestima popular, conflictos con mujeres, pérdida de estado, gasto vano y riesgo para madre o esposa. Se manifiesta frente a otros.',
  'Lilly asocia el Medio Cielo dirigido a la oposición de la Luna con contrariedades por mujeres, pérdida de honor y dignidad, despilfarro, muerte o peligro de madre/esposa, sentencia de magistrado y duración según signo. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.710. Líneas ~30092-30104 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_MC_CONJUNCION',
  'MERCURIO',
  'MC',
  'CONJUNCION',
  'Contacto directo de Mercurio sobre MC: honor por aprendizaje, escritura, cuentas, geometría, comercio e industria. Se nota de forma directa.',
  'Lilly asocia el Medio Cielo dirigido al cuerpo de Mercurio con fortuna en los negocios generales, reputación por sabiduría, aumento patrimonial, mucha actividad, aprendizajes o grados, con posible descrédito si Mercurio está mal. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.708. Líneas ~30017-30029 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_MC_SEXTIL',
  'MERCURIO',
  'MC',
  'SEXTIL',
  'Oportunidad moderada de Mercurio sobre MC: avance por libros, lenguas, comercio, viajes, oficios, mensajes y pluma. Requiere cooperación consciente.',
  'Lilly asocia el Medio Cielo dirigido al sextil de Mercurio con inclinación al estudio, escritura, mercadería, trato con hombres de libros, viajes, embajadas, secretarías y ganancias por documentos. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.708-709. Líneas ~30030-30048 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_MC_CUADRATURA',
  'MERCURIO',
  'MC',
  'CUADRATURA',
  'Tensión activa de Mercurio sobre MC: tiempo ambiguo por informes, pleitos, letras falsas, jueces parciales y pérdida de preferencia. Pide actuar ante la fricción.',
  'Lilly asocia el Medio Cielo dirigido a la cuadratura de Mercurio con tormentos causados por mercuriales o letrados, malinterpretan acciones, provocan litigios, grados frustrados, difamación, falsos testigos y cuentas injustas. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.709. Líneas ~30049-30062 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_MC_TRIGONO',
  'MERCURIO',
  'MC',
  'TRIGONO',
  'Flujo favorable de Mercurio sobre MC: avance por libros, lenguas, comercio, viajes, oficios, mensajes y pluma. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Medio Cielo dirigido al trígono de Mercurio con inclinación al estudio, escritura, mercadería, trato con hombres de libros, viajes, embajadas, secretarías y ganancias por documentos. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.708-709. Líneas ~30030-30048 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_MC_OPOSICION',
  'MERCURIO',
  'MC',
  'OPOSICION',
  'Confrontación externa de Mercurio sobre MC: tiempo ambiguo por informes, pleitos, letras falsas, jueces parciales y pérdida de preferencia. Se manifiesta frente a otros.',
  'Lilly asocia el Medio Cielo dirigido a la oposición de Mercurio con tormentos causados por mercuriales o letrados, malinterpretan acciones, provocan litigios, grados frustrados, difamación, falsos testigos y cuentas injustas. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.709. Líneas ~30049-30062 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_MC_CONJUNCION',
  'VENUS',
  'MC',
  'CONJUNCION',
  'Contacto directo de Venus sobre MC: alegría pública, banquetes, mujeres, comercio grato, matrimonio o preferencia. Se nota de forma directa.',
  'Lilly asocia el Medio Cielo dirigido al cuerpo de Venus con ánimo jovial, trato con jóvenes mujeres, boda u honores por mujeres, buen comercio, amor del pueblo y aceptación del príncipe. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.707. Líneas ~29969-29978 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_MC_SEXTIL',
  'VENUS',
  'MC',
  'SEXTIL',
  'Oportunidad moderada de Venus sobre MC: favor femenino, casas, vestidos, placer, salud, alianza y felicidad pública. Requiere cooperación consciente.',
  'Lilly asocia el Medio Cielo dirigido al sextil de Venus con amor de mujeres, nuevos bienes domésticos, buena voluntad popular, salud, seguridad de madre y parientes, matrimonio o hijo según edad. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.707. Líneas ~29979-29990 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_MC_CUADRATURA',
  'VENUS',
  'MC',
  'CUADRATURA',
  'Tensión activa de Venus sobre MC: escándalo por mujeres, celos, rechazo, pérdida de joyas, divorcio o vida conyugal inquieta. Pide actuar ante la fricción.',
  'Lilly asocia el Medio Cielo dirigido a la cuadratura de Venus con ignominia, detracción de fama, estrife, engaños femeninos, concubinato, muerte de madre o esposa, separación rápida y arrepentimiento. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.707-708. Líneas ~29991-30011 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_MC_TRIGONO',
  'VENUS',
  'MC',
  'TRIGONO',
  'Flujo favorable de Venus sobre MC: favor femenino, casas, vestidos, placer, salud, alianza y felicidad pública. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Medio Cielo dirigido al trígono de Venus con amor de mujeres, nuevos bienes domésticos, buena voluntad popular, salud, seguridad de madre y parientes, matrimonio o hijo según edad. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.707. Líneas ~29979-29990 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_MC_OPOSICION',
  'VENUS',
  'MC',
  'OPOSICION',
  'Confrontación externa de Venus sobre MC: escándalo por mujeres, celos, rechazo, pérdida de joyas, divorcio o vida conyugal inquieta. Se manifiesta frente a otros.',
  'Lilly asocia el Medio Cielo dirigido a la oposición de Venus con ignominia, detracción de fama, estrife, engaños femeninos, concubinato, muerte de madre o esposa, separación rápida y arrepentimiento. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.707-708. Líneas ~29991-30011 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_MC_CONJUNCION',
  'MARTE',
  'MC',
  'CONJUNCION',
  'Contacto directo de Marte sobre MC: crisis pública, ira de poderosos, prisión, exilio y consumo patrimonial violento. Se nota de forma directa.',
  'Lilly asocia el Medio Cielo dirigido al cuerpo de Marte con grandes infortunios inesperados, enemigos marciales, destierro, cárcel, odio, pérdida por fuego o robo y violencia pública si la carta lo permite. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.705. Líneas ~29853-29865 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_MC_SEXTIL',
  'MARTE',
  'MC',
  'SEXTIL',
  'Oportunidad moderada de Marte sobre MC: armas, mando, ejercicios, comercio activo, inventiva y respeto de soldados. Requiere cooperación consciente.',
  'Lilly asocia el Medio Cielo dirigido al sextil de Marte con estimula esgrima, tiro, caza, trato con soldados, preferencia por guerra, actividad mecánica, comercio rápido y preparación militar. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.705. Líneas ~29866-29874 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_MC_CUADRATURA',
  'MARTE',
  'MC',
  'CUADRATURA',
  'Tensión activa de Marte sobre MC: robos, querellas, restricción, acusaciones públicas, pérdida de mando y tumultos. Pide actuar ante la fricción.',
  'Lilly asocia el Medio Cielo dirigido a la cuadratura de Marte con males que proceden de sí mismo y de otros, cárcel, muerte pública si corresponde, acusaciones de fraude monetario, motines y pérdida de ejércitos. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.705. Líneas ~29875-29885 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_MC_TRIGONO',
  'MARTE',
  'MC',
  'TRIGONO',
  'Flujo favorable de Marte sobre MC: armas, mando, ejercicios, comercio activo, inventiva y respeto de soldados. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Medio Cielo dirigido al trígono de Marte con estimula esgrima, tiro, caza, trato con soldados, preferencia por guerra, actividad mecánica, comercio rápido y preparación militar. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.705. Líneas ~29866-29874 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_MC_OPOSICION',
  'MARTE',
  'MC',
  'OPOSICION',
  'Confrontación externa de Marte sobre MC: robos, querellas, restricción, acusaciones públicas, pérdida de mando y tumultos. Se manifiesta frente a otros.',
  'Lilly asocia el Medio Cielo dirigido a la oposición de Marte con males que proceden de sí mismo y de otros, cárcel, muerte pública si corresponde, acusaciones de fraude monetario, motines y pérdida de ejércitos. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.705. Líneas ~29875-29885 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_MC_CONJUNCION',
  'JUPITER',
  'MC',
  'CONJUNCION',
  'Contacto directo de Júpiter sobre MC: promoción honorable, riqueza, patronazgo de clérigos, juristas o personas grandes. Se nota de forma directa.',
  'Lilly asocia el Medio Cielo dirigido al cuerpo de Júpiter con año saludable, provechoso y glorioso, con dignidad, oficio, práctica legal o eclesiástica, altos favores y avance según capacidad. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.703-704. Líneas ~29806-29822 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_MC_SEXTIL',
  'JUPITER',
  'MC',
  'SEXTIL',
  'Oportunidad moderada de Júpiter sobre MC: elevación notable, oficio, dignidad y embajadas si Júpiter está fuerte. Requiere cooperación consciente.',
  'Lilly asocia el Medio Cielo dirigido al sextil de Júpiter con repite lo prometido por el cuerpo de Júpiter y puede levantar al nativo desde condición humilde hacia preferencia o encargo público. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.704. Líneas ~29823-29828 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_MC_CUADRATURA',
  'JUPITER',
  'MC',
  'CUADRATURA',
  'Tensión activa de Júpiter sobre MC: graves molestias legales o religiosas, envidia de superiores y gasto defensivo. Pide actuar ante la fricción.',
  'Lilly asocia el Medio Cielo dirigido a la cuadratura de Júpiter con jueces, abogados, magistrados, nobles o clérigos intentan privarlo de estima u oficio; hay aflicción, defensa costosa y descontento político. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.704. Líneas ~29829-29844 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_MC_TRIGONO',
  'JUPITER',
  'MC',
  'TRIGONO',
  'Flujo favorable de Júpiter sobre MC: elevación notable, oficio, dignidad y embajadas si Júpiter está fuerte. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Medio Cielo dirigido al trígono de Júpiter con repite lo prometido por el cuerpo de Júpiter y puede levantar al nativo desde condición humilde hacia preferencia o encargo público. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.704. Líneas ~29823-29828 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_MC_OPOSICION',
  'JUPITER',
  'MC',
  'OPOSICION',
  'Confrontación externa de Júpiter sobre MC: graves molestias legales o religiosas, envidia de superiores y gasto defensivo. Se manifiesta frente a otros.',
  'Lilly asocia el Medio Cielo dirigido a la oposición de Júpiter con jueces, abogados, magistrados, nobles o clérigos intentan privarlo de estima u oficio; hay aflicción, defensa costosa y descontento político. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.704. Líneas ~29829-29844 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_MC_CONJUNCION',
  'SATURNO',
  'MC',
  'CONJUNCION',
  'Contacto directo de Saturno sobre MC: ira de poderosos, caída de cargo, descrédito público y acciones torpes. Se nota de forma directa.',
  'Lilly asocia el Medio Cielo dirigido al cuerpo de Saturno con enojo de príncipes, magistrados u oficiales, pérdida de honores, mandos y favores, mala gestión, criados rebeldes y riesgo judicial si el radix lo promete. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.702-703. Líneas ~29762-29776 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_MC_SEXTIL',
  'SATURNO',
  'MC',
  'SEXTIL',
  'Oportunidad moderada de Saturno sobre MC: honor por mayores, gravedad, tierras, casas, jardines y bienes saturninos. Requiere cooperación consciente.',
  'Lilly asocia el Medio Cielo dirigido al sextil de Saturno con estima por personas antiguas, sobriedad, provecho por tierras, casas, huertos, bosques y mando local si Saturno está bien situado. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.703. Líneas ~29777-29786 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_MC_CUADRATURA',
  'SATURNO',
  'MC',
  'CUADRATURA',
  'Tensión activa de Saturno sobre MC: pérdida de oficio y reputación por personas bajas, envidias, pobreza o acusaciones. Pide actuar ante la fricción.',
  'Lilly asocia el Medio Cielo dirigido a la cuadratura de Saturno con contratiempos laboriosos, daño por campesinos, obreros, cortesanos falsos o vulgares, descrédito, robos, tumultos o descontento colectivo. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.703. Líneas ~29787-29799 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_MC_TRIGONO',
  'SATURNO',
  'MC',
  'TRIGONO',
  'Flujo favorable de Saturno sobre MC: honor por mayores, gravedad, tierras, casas, jardines y bienes saturninos. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Medio Cielo dirigido al trígono de Saturno con estima por personas antiguas, sobriedad, provecho por tierras, casas, huertos, bosques y mando local si Saturno está bien situado. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.703. Líneas ~29777-29786 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_MC_OPOSICION',
  'SATURNO',
  'MC',
  'OPOSICION',
  'Confrontación externa de Saturno sobre MC: pérdida de oficio y reputación por personas bajas, envidias, pobreza o acusaciones. Se manifiesta frente a otros.',
  'Lilly asocia el Medio Cielo dirigido a la oposición de Saturno con contratiempos laboriosos, daño por campesinos, obreros, cortesanos falsos o vulgares, descrédito, robos, tumultos o descontento colectivo. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLX, p.703. Líneas ~29787-29799 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_SOL_CONJUNCION',
  'LUNA',
  'SOL',
  'CONJUNCION',
  'Contacto directo de la Luna sobre Sol: salud debilitada, humores flemáticos, viaje, matrimonio difícil o esposa imperiosa. Se nota de forma directa.',
  'Lilly asocia el Sol dirigido al cuerpo de la Luna con alteración de cuerpo y estómago, vista turbia, inclinación a viajes y gastos; puede dar oficio si la Luna está dignificada. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.720. Líneas ~30491-30502 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_SOL_SEXTIL',
  'LUNA',
  'SOL',
  'SEXTIL',
  'Oportunidad moderada de la Luna sobre Sol: favor de grandes, encargos honorables, viajes necesarios, esposa rica o embajada. Requiere cooperación consciente.',
  'Lilly asocia el Sol dirigido al sextil de la Luna con amistad de reyes y personas principales, empleos con honor y provecho, viajes distinguidos, matrimonio provechoso y aumento de amigos. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.720. Líneas ~30503-30512 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_SOL_CUADRATURA',
  'LUNA',
  'SOL',
  'CUADRATURA',
  'Tensión activa de la Luna sobre Sol: poderosos adversos, malos viajes, separación familiar, ojos enfermos, fiebre o viruela. Pide actuar ante la fricción.',
  'Lilly asocia el Sol dirigido a la cuadratura de la Luna con hombres fuertes afligen al nativo, pérdida de estado, poca prosperidad, riñas entre padres o cónyuges, mujeres disolutas y enfermedades. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.720-721. Líneas ~30513-30526 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_SOL_TRIGONO',
  'LUNA',
  'SOL',
  'TRIGONO',
  'Flujo favorable de la Luna sobre Sol: favor de grandes, encargos honorables, viajes necesarios, esposa rica o embajada. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Sol dirigido al trígono de la Luna con amistad de reyes y personas principales, empleos con honor y provecho, viajes distinguidos, matrimonio provechoso y aumento de amigos. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.720. Líneas ~30503-30512 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_SOL_OPOSICION',
  'LUNA',
  'SOL',
  'OPOSICION',
  'Confrontación externa de la Luna sobre Sol: poderosos adversos, malos viajes, separación familiar, ojos enfermos, fiebre o viruela. Se manifiesta frente a otros.',
  'Lilly asocia el Sol dirigido a la oposición de la Luna con hombres fuertes afligen al nativo, pérdida de estado, poca prosperidad, riñas entre padres o cónyuges, mujeres disolutas y enfermedades. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.720-721. Líneas ~30513-30526 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_SOL_CONJUNCION',
  'MERCURIO',
  'SOL',
  'CONJUNCION',
  'Contacto directo de Mercurio sobre Sol: muchos negocios, comercio, letras, embajadas, pleitos y mente dispersa. Se nota de forma directa.',
  'Lilly asocia el Sol dirigido al cuerpo de Mercurio con inclinación mercantil y literaria, estima por aprendizaje, mensajes, viajes, controversias, falso testimonio y variación entre estudios. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.719. Líneas ~30449-30462 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_SOL_SEXTIL',
  'MERCURIO',
  'SOL',
  'SEXTIL',
  'Oportunidad moderada de Mercurio sobre Sol: actividad intelectual, escritura, cuentas, libros, estudios y encargos sin gran descanso. Requiere cooperación consciente.',
  'Lilly asocia el Sol dirigido al sextil de Mercurio con ocupación continua, deseo de viaje, preferencia escolar o eclesiástica, concepciones ingeniosas y compra o venta de objetos profesionales. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.719. Líneas ~30463-30470 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_SOL_CUADRATURA',
  'MERCURIO',
  'SOL',
  'CUADRATURA',
  'Tensión activa de Mercurio sobre Sol: acusaciones, falsificación, deudas, pérdida de oficio, aversión al estudio e infamia. Pide actuar ante la fricción.',
  'Lilly asocia el Sol dirigido a la cuadratura de Mercurio con criminaciones por escritos o dinero, clamores injustos, mente afligida, descrédito legal, rechazo del estudio y dificultad de verdadera oposición astronómica. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.719-720. Líneas ~30471-30486 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_SOL_TRIGONO',
  'MERCURIO',
  'SOL',
  'TRIGONO',
  'Flujo favorable de Mercurio sobre Sol: actividad intelectual, escritura, cuentas, libros, estudios y encargos sin gran descanso. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Sol dirigido al trígono de Mercurio con ocupación continua, deseo de viaje, preferencia escolar o eclesiástica, concepciones ingeniosas y compra o venta de objetos profesionales. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.719. Líneas ~30463-30470 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_SOL_OPOSICION',
  'MERCURIO',
  'SOL',
  'OPOSICION',
  'Confrontación externa de Mercurio sobre Sol: acusaciones, falsificación, deudas, pérdida de oficio, aversión al estudio e infamia. Se manifiesta frente a otros.',
  'Lilly asocia el Sol dirigido a la oposición de Mercurio con criminaciones por escritos o dinero, clamores injustos, mente afligida, descrédito legal, rechazo del estudio y dificultad de verdadera oposición astronómica. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.719-720. Líneas ~30471-30486 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_SOL_CONJUNCION',
  'VENUS',
  'SOL',
  'CONJUNCION',
  'Contacto directo de Venus sobre Sol: música, juegos, banquetes, amor, matrimonio, salud y aumento de estado. Se nota de forma directa.',
  'Lilly asocia el Sol dirigido al cuerpo de Venus con placeres venusinos, trato de mujeres, boda feliz si Venus está fuerte, buen cuerpo, éxito de negocios, estima y posible consuelo por hijos. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.717-718. Líneas ~30394-30410 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_SOL_SEXTIL',
  'VENUS',
  'SOL',
  'SEXTIL',
  'Oportunidad moderada de Venus sobre Sol: buen nombre, reputación, oficio, riqueza, amor general, matrimonio o nacimiento. Requiere cooperación consciente.',
  'Lilly asocia el Sol dirigido al sextil de Venus con avance más que vulgar, favor de mujeres y personas eminentes, facilidad en asuntos, deseos justos cumplidos y vida placentera. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.718. Líneas ~30411-30425 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_SOL_CUADRATURA',
  'VENUS',
  'SOL',
  'CUADRATURA',
  'Tensión activa de Venus sobre Sol: esterilidad simbólica, dificultad matrimonial, lujuria, infamia y retrasos amorosos. Pide actuar ante la fricción.',
  'Lilly asocia el Sol dirigido a la cuadratura de Venus con año poco fértil, impedimentos para esposa, desorden sensual, actos sórdidos, escándalo y descrédito, especialmente entendido para la cuadratura. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.718. Líneas ~30426-30436 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_SOL_TRIGONO',
  'VENUS',
  'SOL',
  'TRIGONO',
  'Flujo favorable de Venus sobre Sol: buen nombre, reputación, oficio, riqueza, amor general, matrimonio o nacimiento. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Sol dirigido al trígono de Venus con avance más que vulgar, favor de mujeres y personas eminentes, facilidad en asuntos, deseos justos cumplidos y vida placentera. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.718. Líneas ~30411-30425 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_SOL_OPOSICION',
  'VENUS',
  'SOL',
  'OPOSICION',
  'Confrontación externa de Venus sobre Sol: esterilidad simbólica, dificultad matrimonial, lujuria, infamia y retrasos amorosos. Se manifiesta frente a otros.',
  'Lilly asocia el Sol dirigido a la oposición de Venus con año poco fértil, impedimentos para esposa, desorden sensual, actos sórdidos, escándalo y descrédito, especialmente entendido para la cuadratura. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.718. Líneas ~30426-30436 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_SOL_CONJUNCION',
  'MARTE',
  'SOL',
  'CONJUNCION',
  'Contacto directo de Marte sobre Sol: fiebres agudas, heridas, rostro marcado, enemigos, peligro de fuego, hierro o animales. Se nota de forma directa.',
  'Lilly asocia el Sol dirigido al cuerpo de Marte con exceso de cólera, dolores de cabeza, ojos dañados, heridas por hierro o agua caliente, inconstancia, odio de reyes y riesgo de perro o caballo. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.716. Líneas ~30336-30354 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_SOL_SEXTIL',
  'MARTE',
  'SOL',
  'SEXTIL',
  'Oportunidad moderada de Marte sobre Sol: amistad marcial, armas, mando, viajes, coraje y honra por soldados o capitanes. Requiere cooperación consciente.',
  'Lilly asocia el Sol dirigido al sextil de Marte con sociedad de soldados o nobles marciales, preferencia militar, ejercicio de armas, generosidad, acción valerosa y mucho movimiento. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.716-717. Líneas ~30355-30371 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_SOL_CUADRATURA',
  'MARTE',
  'SOL',
  'CUADRATURA',
  'Tensión activa de Marte sobre Sol: enfermedad aguda, ojos dañados, heridas, peligro vital y fracaso de acciones. Pide actuar ante la fricción.',
  'Lilly asocia el Sol dirigido a la cuadratura de Marte con fiebres altas, locura o pérdida de sentidos, fuego, hierro o golpes, robo en caminos, mal nombre y muerte si concurren año crítico y anareta. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.717. Líneas ~30372-30386 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_SOL_TRIGONO',
  'MARTE',
  'SOL',
  'TRIGONO',
  'Flujo favorable de Marte sobre Sol: amistad marcial, armas, mando, viajes, coraje y honra por soldados o capitanes. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Sol dirigido al trígono de Marte con sociedad de soldados o nobles marciales, preferencia militar, ejercicio de armas, generosidad, acción valerosa y mucho movimiento. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.716-717. Líneas ~30355-30371 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_SOL_OPOSICION',
  'MARTE',
  'SOL',
  'OPOSICION',
  'Confrontación externa de Marte sobre Sol: enfermedad aguda, ojos dañados, heridas, peligro vital y fracaso de acciones. Se manifiesta frente a otros.',
  'Lilly asocia el Sol dirigido a la oposición de Marte con fiebres altas, locura o pérdida de sentidos, fuego, hierro o golpes, robo en caminos, mal nombre y muerte si concurren año crítico y anareta. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.717. Líneas ~30372-30386 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_SOL_CONJUNCION',
  'JUPITER',
  'SOL',
  'CONJUNCION',
  'Contacto directo de Júpiter sobre Sol: salud, paz mental, honores, cargo, dignidad y favor de personas eminentes. Se nota de forma directa.',
  'Lilly asocia el Sol dirigido al cuerpo de Júpiter con cuerpo sano, disfrute de fortuna, preferencia eclesiástica o jurídica, estima entre reyes, juristas y grandes, paz política y obediencia. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.715. Líneas ~30288-30299 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_SOL_SEXTIL',
  'JUPITER',
  'SOL',
  'SEXTIL',
  'Oportunidad moderada de Júpiter sobre Sol: juicio sólido, oficio, mando, confianza pública, riqueza y posible hijo. Requiere cooperación consciente.',
  'Lilly asocia el Sol dirigido al sextil de Júpiter con honor por manejar asuntos, gratificaciones de superiores, cargo civil, ley o iglesia, aumento patrimonial y preservación del cuerpo. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.715. Líneas ~30300-30313 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_SOL_CUADRATURA',
  'JUPITER',
  'SOL',
  'CUADRATURA',
  'Tensión activa de Júpiter sobre Sol: oposición de religiosos, abogados o nobles, gastos y afrentas superables. Pide actuar ante la fricción.',
  'Lilly asocia el Sol dirigido a la cuadratura de Júpiter con personas de ley o religión impiden negocios, gastan el estado y desacreditan; puede recuperarse si la genitura no es adversa. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.715-716. Líneas ~30314-30328 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_SOL_TRIGONO',
  'JUPITER',
  'SOL',
  'TRIGONO',
  'Flujo favorable de Júpiter sobre Sol: juicio sólido, oficio, mando, confianza pública, riqueza y posible hijo. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Sol dirigido al trígono de Júpiter con honor por manejar asuntos, gratificaciones de superiores, cargo civil, ley o iglesia, aumento patrimonial y preservación del cuerpo. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.715. Líneas ~30300-30313 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_SOL_OPOSICION',
  'JUPITER',
  'SOL',
  'OPOSICION',
  'Confrontación externa de Júpiter sobre Sol: oposición de religiosos, abogados o nobles, gastos y afrentas superables. Se manifiesta frente a otros.',
  'Lilly asocia el Sol dirigido a la oposición de Júpiter con personas de ley o religión impiden negocios, gastan el estado y desacreditan; puede recuperarse si la genitura no es adversa. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.715-716. Líneas ~30314-30328 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_SOL_CONJUNCION',
  'SATURNO',
  'SOL',
  'CONJUNCION',
  'Contacto directo de Saturno sobre Sol: enfermedad, melancolía, ojo derecho sensible, padre afectado y enemigos saturninos. Se nota de forma directa.',
  'Lilly asocia el Sol dirigido al cuerpo de Saturno con dificultades, debilidad del corazón, vientre o cabeza, cuartanas, males crónicos, frialdad ocular, injuria del padre y cruces de nobles saturninos. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.713-714. Líneas ~30235-30255 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_SOL_SEXTIL',
  'SATURNO',
  'SOL',
  'SEXTIL',
  'Oportunidad moderada de Saturno sobre Sol: honor de mayores, gravedad, riqueza por tierras, arquitectura o herencia. Requiere cooperación consciente.',
  'Lilly asocia el Sol dirigido al sextil de Saturno con marcas de estima de un hombre antiguo o magistrado, preferencia, moderación, gloria, bienes rurales y herencia casual. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.714. Líneas ~30256-30262 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_SOL_CUADRATURA',
  'SATURNO',
  'SOL',
  'CUADRATURA',
  'Tensión activa de Saturno sobre Sol: enfermedad severa, caída, pérdida de fortuna, fama y padre, con riesgos marítimos. Pide actuar ante la fricción.',
  'Lilly asocia el Sol dirigido a la cuadratura de Saturno con ojos débiles, caída de caballo o edificio, destrucción patrimonial, robo por criados o campesinos, pérdida de honor, naufragios y conmociones. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.714-715. Líneas ~30263-30282 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_SOL_TRIGONO',
  'SATURNO',
  'SOL',
  'TRIGONO',
  'Flujo favorable de Saturno sobre Sol: honor de mayores, gravedad, riqueza por tierras, arquitectura o herencia. Tiende a fluir con apoyo natural.',
  'Lilly asocia el Sol dirigido al trígono de Saturno con marcas de estima de un hombre antiguo o magistrado, preferencia, moderación, gloria, bienes rurales y herencia casual. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.714. Líneas ~30256-30262 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_SOL_OPOSICION',
  'SATURNO',
  'SOL',
  'OPOSICION',
  'Confrontación externa de Saturno sobre Sol: enfermedad severa, caída, pérdida de fortuna, fama y padre, con riesgos marítimos. Se manifiesta frente a otros.',
  'Lilly asocia el Sol dirigido a la oposición de Saturno con ojos débiles, caída de caballo o edificio, destrucción patrimonial, robo por criados o campesinos, pérdida de honor, naufragios y conmociones. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXII, p.714-715. Líneas ~30263-30282 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_LUNA_CONJUNCION',
  'SOL',
  'LUNA',
  'CONJUNCION',
  'Contacto directo del Sol sobre Luna: fiebres ardientes, secretos revelados, cambio de estado, ojos sensibles y matrimonio. Se nota de forma directa.',
  'Lilly asocia la Luna dirigida al cuerpo del Sol con calor febril, publicación de lo oculto, expectativas y frenos súbitos, temor mental, honra paterna en cartas altas y boda o cambio vital en comunes. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.730. Líneas ~30880-30894 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_LUNA_SEXTIL',
  'SOL',
  'LUNA',
  'SEXTIL',
  'Oportunidad moderada del Sol sobre Luna: amistad de mujeres nobles, favor popular, cargo de confianza, viajes y matrimonio. Requiere cooperación consciente.',
  'Lilly asocia la Luna dirigida al sextil del Sol con acquaintance honorable, estima del pueblo, oficina rica y honorable, prudencia recompensada, viajes ultramarinos y comercio libre. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.730. Líneas ~30895-30911 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_LUNA_CUADRATURA',
  'SOL',
  'LUNA',
  'CUADRATURA',
  'Tensión activa del Sol sobre Luna: peligros corporales y mentales, ira, pérdida de favor, fiebres, ojos y oposición de superiores. Pide actuar ante la fricción.',
  'Lilly asocia la Luna dirigida a la cuadratura del Sol con tormentos, tumultos populares, amistades nobles fingidas, enfermedades de ojos, cólicos y flujos; puede activar caída o muerte violenta si el radix lo promete. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.731. Líneas ~30915-30938 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_LUNA_TRIGONO',
  'SOL',
  'LUNA',
  'TRIGONO',
  'Flujo favorable del Sol sobre Luna: amistad de mujeres nobles, favor popular, cargo de confianza, viajes y matrimonio. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Luna dirigida al trígono del Sol con acquaintance honorable, estima del pueblo, oficina rica y honorable, prudencia recompensada, viajes ultramarinos y comercio libre. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.730. Líneas ~30895-30911 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_LUNA_OPOSICION',
  'SOL',
  'LUNA',
  'OPOSICION',
  'Confrontación externa del Sol sobre Luna: peligros corporales y mentales, ira, pérdida de favor, fiebres, ojos y oposición de superiores. Se manifiesta frente a otros.',
  'Lilly asocia la Luna dirigida a la oposición del Sol con tormentos, tumultos populares, amistades nobles fingidas, enfermedades de ojos, cólicos y flujos; puede activar caída o muerte violenta si el radix lo promete. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.731. Líneas ~30915-30938 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_LUNA_CONJUNCION',
  'MERCURIO',
  'LUNA',
  'CONJUNCION',
  'Contacto directo de Mercurio sobre Luna: controversias, ingenio, engaños, comercio, cuentas, viajes y noticias. Se nota de forma directa.',
  'Lilly asocia la Luna dirigida al cuerpo de Mercurio con muchas causas, sutileza, elocuencia, falsificaciones si está torcido, estudio provechoso, misivas, noticias extranjeras y actividad mercantil. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.732-733. Líneas ~30987-31002 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_LUNA_SEXTIL',
  'MERCURIO',
  'LUNA',
  'SEXTIL',
  'Oportunidad moderada de Mercurio sobre Luna: empleos con éxito, letras, cuentas, música, viajes y amistad o fortuna por mujer noble. Requiere cooperación consciente.',
  'Lilly asocia la Luna dirigida al sextil de Mercurio con bendice ocupaciones, lectura, escritura, administración, gusto musical, viajes, secretarías, embajadas y mucho tráfico vital. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.733. Líneas ~31003-31012 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_LUNA_CUADRATURA',
  'MERCURIO',
  'LUNA',
  'CUADRATURA',
  'Tensión activa de Mercurio sobre Luna: aversión al estudio, tumultos, escritos falsos, cárcel, destierro o confusión mental. Pide actuar ante la fricción.',
  'Lilly asocia la Luna dirigida a la cuadratura de Mercurio con declina de hombres de saber, ira popular, contratos o monedas fraudulentas, engaño, prisión, sentencia grave, delirio, escándalos y cuentas. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.733. Líneas ~31013-31022 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_LUNA_TRIGONO',
  'MERCURIO',
  'LUNA',
  'TRIGONO',
  'Flujo favorable de Mercurio sobre Luna: empleos con éxito, letras, cuentas, música, viajes y amistad o fortuna por mujer noble. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Luna dirigida al trígono de Mercurio con bendice ocupaciones, lectura, escritura, administración, gusto musical, viajes, secretarías, embajadas y mucho tráfico vital. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.733. Líneas ~31003-31012 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_LUNA_OPOSICION',
  'MERCURIO',
  'LUNA',
  'OPOSICION',
  'Confrontación externa de Mercurio sobre Luna: aversión al estudio, tumultos, escritos falsos, cárcel, destierro o confusión mental. Se manifiesta frente a otros.',
  'Lilly asocia la Luna dirigida a la oposición de Mercurio con declina de hombres de saber, ira popular, contratos o monedas fraudulentas, engaño, prisión, sentencia grave, delirio, escándalos y cuentas. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.733. Líneas ~31013-31022 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_LUNA_CONJUNCION',
  'VENUS',
  'LUNA',
  'CONJUNCION',
  'Contacto directo de Venus sobre Luna: tiempo alegre, placer, amor, regalos de mujeres, salud y paz social. Se nota de forma directa.',
  'Lilly asocia la Luna dirigida al cuerpo de Venus con jocosidad, teatro, danza y deleites, constitución sana, enamoramiento, provecho por mujeres, matrimonio y comercio libre. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.731-732. Líneas ~30939-30958 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_LUNA_SEXTIL',
  'VENUS',
  'LUNA',
  'SEXTIL',
  'Oportunidad moderada de Venus sobre Luna: éxito en asuntos, matrimonio feliz, salud, amor familiar y comercio libre. Requiere cooperación consciente.',
  'Lilly asocia la Luna dirigida al sextil de Venus con vida placentera, sucesión de negocios, boda con persona amada, hijos obedientes, parientes concordes y aumento mercantil. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.732. Líneas ~30959-30969 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_LUNA_CUADRATURA',
  'VENUS',
  'LUNA',
  'CUADRATURA',
  'Tensión activa de Venus sobre Luna: deseo desordenado, gasto, escándalo, adulterio, boda infeliz y males venéreos. Pide actuar ante la fricción.',
  'Lilly asocia la Luna dirigida a la cuadratura de Venus con afecto errante por mujeres, consumo de estado, infamia, controversias femeninas, matrimonio no amado y enfermedades según edad y signo. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.732. Líneas ~30970-30981 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_LUNA_TRIGONO',
  'VENUS',
  'LUNA',
  'TRIGONO',
  'Flujo favorable de Venus sobre Luna: éxito en asuntos, matrimonio feliz, salud, amor familiar y comercio libre. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Luna dirigida al trígono de Venus con vida placentera, sucesión de negocios, boda con persona amada, hijos obedientes, parientes concordes y aumento mercantil. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.732. Líneas ~30959-30969 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_LUNA_OPOSICION',
  'VENUS',
  'LUNA',
  'OPOSICION',
  'Confrontación externa de Venus sobre Luna: deseo desordenado, gasto, escándalo, adulterio, boda infeliz y males venéreos. Se manifiesta frente a otros.',
  'Lilly asocia la Luna dirigida a la oposición de Venus con afecto errante por mujeres, consumo de estado, infamia, controversias femeninas, matrimonio no amado y enfermedades según edad y signo. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.732. Líneas ~30970-30981 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_LUNA_CONJUNCION',
  'MARTE',
  'LUNA',
  'CONJUNCION',
  'Contacto directo de Marte sobre Luna: prisión, ansiedad, pérdida, fiebre, heridas, ojos débiles y peligro por fuego o hierro. Se nota de forma directa.',
  'Lilly asocia la Luna dirigida al cuerpo de Marte con muchos infortunios mundanos, enemigos, enfermedad aguda, partes secretas, armas, disparos, fuego, bestias, cólera y pelea. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.728. Líneas ~30808-30825 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_LUNA_SEXTIL',
  'MARTE',
  'LUNA',
  'SEXTIL',
  'Oportunidad moderada de Marte sobre Luna: ánimo marcial, audacia, ejercicios, caballos, armas, comercio y ganancia activa. Requiere cooperación consciente.',
  'Lilly asocia la Luna dirigida al sextil de Marte con majestad, industria, vigilancia, deportes y asuntos militares; puede dar beneficio, respeto y aumento de fortuna, aunque gasto por mujeres o caballos. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.728-729. Líneas ~30826-30848 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_LUNA_CUADRATURA',
  'MARTE',
  'LUNA',
  'CUADRATURA',
  'Tensión activa de Marte sobre Luna: sentidos turbados, fiebre, escándalos, mujeres adversas, heridas, ojos y naufragio. Pide actuar ante la fricción.',
  'Lilly asocia la Luna dirigida a la cuadratura de Marte con locura o frenesí, mala esposa, pérdida de bienes, enfermedades venéreas o renales, desprecio femenino, heridas por ganado y ruina comercial marítima. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.729. Líneas ~30849-30870 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_LUNA_TRIGONO',
  'MARTE',
  'LUNA',
  'TRIGONO',
  'Flujo favorable de Marte sobre Luna: ánimo marcial, audacia, ejercicios, caballos, armas, comercio y ganancia activa. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Luna dirigida al trígono de Marte con majestad, industria, vigilancia, deportes y asuntos militares; puede dar beneficio, respeto y aumento de fortuna, aunque gasto por mujeres o caballos. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.728-729. Líneas ~30826-30848 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_LUNA_OPOSICION',
  'MARTE',
  'LUNA',
  'OPOSICION',
  'Confrontación externa de Marte sobre Luna: sentidos turbados, fiebre, escándalos, mujeres adversas, heridas, ojos y naufragio. Se manifiesta frente a otros.',
  'Lilly asocia la Luna dirigida a la oposición de Marte con locura o frenesí, mala esposa, pérdida de bienes, enfermedades venéreas o renales, desprecio femenino, heridas por ganado y ruina comercial marítima. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.729. Líneas ~30849-30870 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_LUNA_CONJUNCION',
  'JUPITER',
  'LUNA',
  'CONJUNCION',
  'Contacto directo de Júpiter sobre Luna: salud, honor, riqueza, viajes prósperos, mando y grados universitarios. Se nota de forma directa.',
  'Lilly asocia la Luna dirigida al cuerpo de Júpiter con cuerpo sano, gran honor con bienes, derrota de adversarios, alegría, dominio u oficio sobre el pueblo, grados legales o universitarios. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.727. Líneas ~30765-30776 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_LUNA_SEXTIL',
  'JUPITER',
  'LUNA',
  'SEXTIL',
  'Oportunidad moderada de Júpiter sobre Luna: honor aumentado, preferencia, amistades nobles, ley, iglesia y beneficio. Requiere cooperación consciente.',
  'Lilly asocia la Luna dirigida al sextil de Júpiter con eleva desde grado bajo, acerca a eminentes, ministros, juristas, caballeros y nobles, y promete amistad y provecho en iglesia o ley. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.727. Líneas ~30777-30785 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_LUNA_CUADRATURA',
  'JUPITER',
  'LUNA',
  'CUADRATURA',
  'Tensión activa de Júpiter sobre Luna: dificultades en cargo, abogados o religiosos adversos, trabajo y victoria tardía. Pide actuar ante la fricción.',
  'Lilly asocia la Luna dirigida a la cuadratura de Júpiter con mente atormentada por ocasiones difíciles, crédito atacado por juristas o clérigos, pero preferencia al final por virtud y constancia. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.727-728. Líneas ~30786-30802 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_LUNA_TRIGONO',
  'JUPITER',
  'LUNA',
  'TRIGONO',
  'Flujo favorable de Júpiter sobre Luna: honor aumentado, preferencia, amistades nobles, ley, iglesia y beneficio. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Luna dirigida al trígono de Júpiter con eleva desde grado bajo, acerca a eminentes, ministros, juristas, caballeros y nobles, y promete amistad y provecho en iglesia o ley. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.727. Líneas ~30777-30785 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_LUNA_OPOSICION',
  'JUPITER',
  'LUNA',
  'OPOSICION',
  'Confrontación externa de Júpiter sobre Luna: dificultades en cargo, abogados o religiosos adversos, trabajo y victoria tardía. Se manifiesta frente a otros.',
  'Lilly asocia la Luna dirigida a la oposición de Júpiter con mente atormentada por ocasiones difíciles, crédito atacado por juristas o clérigos, pero preferencia al final por virtud y constancia. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.727-728. Líneas ~30786-30802 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_LUNA_CONJUNCION',
  'SATURNO',
  'LUNA',
  'CONJUNCION',
  'Contacto directo de Saturno sobre Luna: males fríos y húmedos, pleitos con autoridad, criados dañinos y tristeza. Se nota de forma directa.',
  'Lilly asocia la Luna dirigida al cuerpo de Saturno con apoplejía, parálisis, hidropesía, gota, fiebres melancólicas o flemáticas, calumnias, pérdida de ganado, angustia y catarros. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.725-726. Líneas ~30708-30728 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  8
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_LUNA_SEXTIL',
  'SATURNO',
  'LUNA',
  'SEXTIL',
  'Oportunidad moderada de Saturno sobre Luna: recomendaciones felices, dones de mayores, respeto popular y provecho rural. Requiere cooperación consciente.',
  'Lilly asocia la Luna dirigida al sextil de Saturno con amistad de hombres dignos, actos meritorios, regalos de mujeres ancianas, honra del común, edificios, estanques, huertos y ganancia por ganado. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.726. Líneas ~30728-30740 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_LUNA_CUADRATURA',
  'SATURNO',
  'LUNA',
  'CUADRATURA',
  'Tensión activa de Saturno sobre Luna: humores malos, fiebres, lentitud, pérdidas por criados, esposa o tierras. Pide actuar ante la fricción.',
  'Lilly asocia la Luna dirigida a la cuadratura de Saturno con cuerpo flemático, torpeza, robos de campesinos y sirvientes, patrimonio materno malgastado, riñas con esposa, madre en peligro y mar inseguro. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.726-727. Líneas ~30740-30757 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_LUNA_TRIGONO',
  'SATURNO',
  'LUNA',
  'TRIGONO',
  'Flujo favorable de Saturno sobre Luna: recomendaciones felices, dones de mayores, respeto popular y provecho rural. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Luna dirigida al trígono de Saturno con amistad de hombres dignos, actos meritorios, regalos de mujeres ancianas, honra del común, edificios, estanques, huertos y ganancia por ganado. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.726. Líneas ~30728-30740 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_LUNA_OPOSICION',
  'SATURNO',
  'LUNA',
  'OPOSICION',
  'Confrontación externa de Saturno sobre Luna: humores malos, fiebres, lentitud, pérdidas por criados, esposa o tierras. Se manifiesta frente a otros.',
  'Lilly asocia la Luna dirigida a la oposición de Saturno con cuerpo flemático, torpeza, robos de campesinos y sirvientes, patrimonio materno malgastado, riñas con esposa, madre en peligro y mar inseguro. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXIIII, p.726-727. Líneas ~30740-30757 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_PARTFORTUNA_CONJUNCION',
  'SOL',
  'PARTFORTUNA',
  'CONJUNCION',
  'Contacto directo del Sol sobre Parte de Fortuna: gastos honorables, liberalidad, prodigalidad y poca conservación de bienes. Se nota de forma directa.',
  'Lilly asocia la Parte de Fortuna dirigida al cuerpo del Sol con desembolso en empresa digna o por príncipe, mayor liberalidad, distribución libre de dinero y consumo de estado por amplitud de corazón. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738-739. Líneas ~31216-31228 del fichero lilly_christian_astrology_completo.txt. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_PARTFORTUNA_SEXTIL',
  'SOL',
  'PARTFORTUNA',
  'SEXTIL',
  'Oportunidad moderada del Sol sobre Parte de Fortuna: ocasión de honor o provecho por superiores, empleo rentable y amistades útiles. Requiere cooperación consciente.',
  'Lilly asocia la Parte de Fortuna dirigida al sextil del Sol con tiempo conveniente para buscar honra o ganancia, ventaja por personas de rango mayor, benevolencia general y empleo que trae beneficio aunque se ahorre poco. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31229-31235 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_PARTFORTUNA_CUADRATURA',
  'SOL',
  'PARTFORTUNA',
  'CUADRATURA',
  'Tensión activa del Sol sobre Parte de Fortuna: daño por pleitos, envidia de grandes, acusaciones, pérdida de oficio o sobornos. Pide actuar ante la fricción.',
  'Lilly asocia la Parte de Fortuna dirigida a la cuadratura del Sol con consumo de tesoro por trajes legales, acusaciones de poderosos, pérdida del oficio o necesidad de dádivas fuertes para conservarlo. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31236-31241 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_PARTFORTUNA_TRIGONO',
  'SOL',
  'PARTFORTUNA',
  'TRIGONO',
  'Flujo favorable del Sol sobre Parte de Fortuna: ocasión de honor o provecho por superiores, empleo rentable y amistades útiles. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Parte de Fortuna dirigida al trígono del Sol con tiempo conveniente para buscar honra o ganancia, ventaja por personas de rango mayor, benevolencia general y empleo que trae beneficio aunque se ahorre poco. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31229-31235 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SOL_PARTFORTUNA_OPOSICION',
  'SOL',
  'PARTFORTUNA',
  'OPOSICION',
  'Confrontación externa del Sol sobre Parte de Fortuna: daño por pleitos, envidia de grandes, acusaciones, pérdida de oficio o sobornos. Se manifiesta frente a otros.',
  'Lilly asocia la Parte de Fortuna dirigida a la oposición del Sol con consumo de tesoro por trajes legales, acusaciones de poderosos, pérdida del oficio o necesidad de dádivas fuertes para conservarlo. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal del Sol y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31236-31241 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_PARTFORTUNA_CONJUNCION',
  'LUNA',
  'PARTFORTUNA',
  'CONJUNCION',
  'Contacto directo de la Luna sobre Parte de Fortuna: amistad y provecho por mujeres o pueblo, viaje, empleo constante y bolsa común. Se nota de forma directa.',
  'Lilly asocia la Parte de Fortuna dirigida al cuerpo de la Luna con asistencia femenina, aumento de fortuna privada por mujeres, mucha acción con gente vulgar, beneficio por sus bolsas, mar o larga jornada. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.740. Líneas ~31283-31290 del fichero lilly_christian_astrology_completo.txt. Lilly agrupa aquí el cuerpo con otros aspectos de la Parte de Fortuna. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_PARTFORTUNA_SEXTIL',
  'LUNA',
  'PARTFORTUNA',
  'SEXTIL',
  'Oportunidad moderada de la Luna sobre Parte de Fortuna: amistad y provecho por mujeres o pueblo, viaje, empleo constante y bolsa común. Requiere cooperación consciente.',
  'Lilly asocia la Parte de Fortuna dirigida al sextil de la Luna con asistencia femenina, aumento de fortuna privada por mujeres, mucha acción con gente vulgar, beneficio por sus bolsas, mar o larga jornada. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.740. Líneas ~31283-31290 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_PARTFORTUNA_CUADRATURA',
  'LUNA',
  'PARTFORTUNA',
  'CUADRATURA',
  'Tensión activa de la Luna sobre Parte de Fortuna: prejuicio en comercio, marineros, deuda, mujer principal adversa, pérdida de crédito y pleitos. Pide actuar ante la fricción.',
  'Lilly asocia la Parte de Fortuna dirigida a la cuadratura de la Luna con daño por contratos o comercio vulgar, perjuicio marítimo, odio de una mujer importante, deuda con muchos, disgusto popular, descrédito y litigios. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.740. Líneas ~31291-31297 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_PARTFORTUNA_TRIGONO',
  'LUNA',
  'PARTFORTUNA',
  'TRIGONO',
  'Flujo favorable de la Luna sobre Parte de Fortuna: amistad y provecho por mujeres o pueblo, viaje, empleo constante y bolsa común. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Parte de Fortuna dirigida al trígono de la Luna con asistencia femenina, aumento de fortuna privada por mujeres, mucha acción con gente vulgar, beneficio por sus bolsas, mar o larga jornada. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.740. Líneas ~31283-31290 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'LUNA_PARTFORTUNA_OPOSICION',
  'LUNA',
  'PARTFORTUNA',
  'OPOSICION',
  'Confrontación externa de la Luna sobre Parte de Fortuna: prejuicio en comercio, marineros, deuda, mujer principal adversa, pérdida de crédito y pleitos. Se manifiesta frente a otros.',
  'Lilly asocia la Parte de Fortuna dirigida a la oposición de la Luna con daño por contratos o comercio vulgar, perjuicio marítimo, odio de una mujer importante, deuda con muchos, disgusto popular, descrédito y litigios. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de la Luna y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.740. Líneas ~31291-31297 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_PARTFORTUNA_CONJUNCION',
  'MERCURIO',
  'PARTFORTUNA',
  'CONJUNCION',
  'Contacto directo de Mercurio sobre Parte de Fortuna: ganancia por contratos, cuentas, ley, universidad, ingenio, comercio, viajes y oficio. Se nota de forma directa.',
  'Lilly asocia la Parte de Fortuna dirigida al cuerpo de Mercurio con aumento de fortuna por tratos, aprendizaje, derecho, estudio, propia industria, herencia imprevista, navegación, comercio marítimo o jornada larga. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739-740. Líneas ~31260-31274 del fichero lilly_christian_astrology_completo.txt. Lilly agrupa aquí el cuerpo con otros aspectos de la Parte de Fortuna. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_PARTFORTUNA_SEXTIL',
  'MERCURIO',
  'PARTFORTUNA',
  'SEXTIL',
  'Oportunidad moderada de Mercurio sobre Parte de Fortuna: ganancia por contratos, cuentas, ley, universidad, ingenio, comercio, viajes y oficio. Requiere cooperación consciente.',
  'Lilly asocia la Parte de Fortuna dirigida al sextil de Mercurio con aumento de fortuna por tratos, aprendizaje, derecho, estudio, propia industria, herencia imprevista, navegación, comercio marítimo o jornada larga. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739-740. Líneas ~31260-31274 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_PARTFORTUNA_CUADRATURA',
  'MERCURIO',
  'PARTFORTUNA',
  'CUADRATURA',
  'Tensión activa de Mercurio sobre Parte de Fortuna: lucha con abogados, cuentas falsas, escritos fraudulentos, pleitos y poco éxito con hijos. Pide actuar ante la fricción.',
  'Lilly asocia la Parte de Fortuna dirigida a la cuadratura de Mercurio con forcejeo con letrados, engaños contables, pérdidas por conceptos ingeniosos, falsos testigos, crédito cuestionado, demandas y frustración con hijos. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.740. Líneas ~31275-31282 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_PARTFORTUNA_TRIGONO',
  'MERCURIO',
  'PARTFORTUNA',
  'TRIGONO',
  'Flujo favorable de Mercurio sobre Parte de Fortuna: ganancia por contratos, cuentas, ley, universidad, ingenio, comercio, viajes y oficio. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Parte de Fortuna dirigida al trígono de Mercurio con aumento de fortuna por tratos, aprendizaje, derecho, estudio, propia industria, herencia imprevista, navegación, comercio marítimo o jornada larga. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739-740. Líneas ~31260-31274 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MERCURIO_PARTFORTUNA_OPOSICION',
  'MERCURIO',
  'PARTFORTUNA',
  'OPOSICION',
  'Confrontación externa de Mercurio sobre Parte de Fortuna: lucha con abogados, cuentas falsas, escritos fraudulentos, pleitos y poco éxito con hijos. Se manifiesta frente a otros.',
  'Lilly asocia la Parte de Fortuna dirigida a la oposición de Mercurio con forcejeo con letrados, engaños contables, pérdidas por conceptos ingeniosos, falsos testigos, crédito cuestionado, demandas y frustración con hijos. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Mercurio y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.740. Líneas ~31275-31282 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_PARTFORTUNA_CONJUNCION',
  'VENUS',
  'PARTFORTUNA',
  'CONJUNCION',
  'Contacto directo de Venus sobre Parte de Fortuna: regalos de damas, ropas, belleza, placer y gasto libre de lo recibido. Se nota de forma directa.',
  'Lilly asocia la Parte de Fortuna dirigida al cuerpo de Venus con grandes dones de una dama o mujer de calidad, gasto generoso de lo obtenido, compra o regalo de vestidos y gusto por la elegancia. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31242-31249 del fichero lilly_christian_astrology_completo.txt. Lilly agrupa aquí el cuerpo con otros aspectos de la Parte de Fortuna. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_PARTFORTUNA_SEXTIL',
  'VENUS',
  'PARTFORTUNA',
  'SEXTIL',
  'Oportunidad moderada de Venus sobre Parte de Fortuna: regalos de damas, ropas, belleza, placer y gasto libre de lo recibido. Requiere cooperación consciente.',
  'Lilly asocia la Parte de Fortuna dirigida al sextil de Venus con grandes dones de una dama o mujer de calidad, gasto generoso de lo obtenido, compra o regalo de vestidos y gusto por la elegancia. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31242-31249 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_PARTFORTUNA_CUADRATURA',
  'VENUS',
  'PARTFORTUNA',
  'CUADRATURA',
  'Tensión activa de Venus sobre Parte de Fortuna: gasto vano por mujeres, amores nuevos, escándalo, regalos inútiles y patrimonio consumido. Pide actuar ante la fricción.',
  'Lilly asocia la Parte de Fortuna dirigida a la cuadratura de Venus con tesoro perdido por mujeres, disputas y odios provocados por ellas, compañías desordenadas, dádivas de poco fruto, exceso y decadencia patrimonial. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31250-31259 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_PARTFORTUNA_TRIGONO',
  'VENUS',
  'PARTFORTUNA',
  'TRIGONO',
  'Flujo favorable de Venus sobre Parte de Fortuna: regalos de damas, ropas, belleza, placer y gasto libre de lo recibido. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Parte de Fortuna dirigida al trígono de Venus con grandes dones de una dama o mujer de calidad, gasto generoso de lo obtenido, compra o regalo de vestidos y gusto por la elegancia. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31242-31249 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'VENUS_PARTFORTUNA_OPOSICION',
  'VENUS',
  'PARTFORTUNA',
  'OPOSICION',
  'Confrontación externa de Venus sobre Parte de Fortuna: gasto vano por mujeres, amores nuevos, escándalo, regalos inútiles y patrimonio consumido. Se manifiesta frente a otros.',
  'Lilly asocia la Parte de Fortuna dirigida a la oposición de Venus con tesoro perdido por mujeres, disputas y odios provocados por ellas, compañías desordenadas, dádivas de poco fruto, exceso y decadencia patrimonial. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Venus y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.739. Líneas ~31250-31259 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_PARTFORTUNA_CONJUNCION',
  'MARTE',
  'PARTFORTUNA',
  'CONJUNCION',
  'Contacto directo de Marte sobre Parte de Fortuna: desgaste por criados, ladrones, soldados, fuego, casas rotas, pleitos y riñas. Se nota de forma directa.',
  'Lilly asocia la Parte de Fortuna dirigida al cuerpo de Marte con derroche de sustancia por sirvientes ladrones, robos de soldados, incendio o fractura de casas, juego, cursos ociosos, pleitos y palabras ásperas. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31211-31215 del fichero lilly_christian_astrology_completo.txt. Lilly agrupa aquí el cuerpo con otros aspectos de la Parte de Fortuna. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_PARTFORTUNA_SEXTIL',
  'MARTE',
  'PARTFORTUNA',
  'SEXTIL',
  'Oportunidad moderada de Marte sobre Parte de Fortuna: riqueza por marciales, armas, caballos, pequeños animales o aventuras marítimas. Requiere cooperación consciente.',
  'Lilly asocia la Parte de Fortuna dirigida al sextil de Marte con aumento por amistad de personas marciales, compraventa de armas o caballos, tráfico de animales pequeños y empresa por mar. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31205-31210 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_PARTFORTUNA_CUADRATURA',
  'MARTE',
  'PARTFORTUNA',
  'CUADRATURA',
  'Tensión activa de Marte sobre Parte de Fortuna: desgaste por criados, ladrones, soldados, fuego, casas rotas, pleitos y riñas. Pide actuar ante la fricción.',
  'Lilly asocia la Parte de Fortuna dirigida a la cuadratura de Marte con derroche de sustancia por sirvientes ladrones, robos de soldados, incendio o fractura de casas, juego, cursos ociosos, pleitos y palabras ásperas. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31211-31215 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_PARTFORTUNA_TRIGONO',
  'MARTE',
  'PARTFORTUNA',
  'TRIGONO',
  'Flujo favorable de Marte sobre Parte de Fortuna: riqueza por marciales, armas, caballos, pequeños animales o aventuras marítimas. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Parte de Fortuna dirigida al trígono de Marte con aumento por amistad de personas marciales, compraventa de armas o caballos, tráfico de animales pequeños y empresa por mar. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31205-31210 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'MARTE_PARTFORTUNA_OPOSICION',
  'MARTE',
  'PARTFORTUNA',
  'OPOSICION',
  'Confrontación externa de Marte sobre Parte de Fortuna: desgaste por criados, ladrones, soldados, fuego, casas rotas, pleitos y riñas. Se manifiesta frente a otros.',
  'Lilly asocia la Parte de Fortuna dirigida a la oposición de Marte con derroche de sustancia por sirvientes ladrones, robos de soldados, incendio o fractura de casas, juego, cursos ociosos, pleitos y palabras ásperas. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Marte y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31211-31215 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_PARTFORTUNA_CONJUNCION',
  'JUPITER',
  'PARTFORTUNA',
  'CONJUNCION',
  'Contacto directo de Júpiter sobre Parte de Fortuna: dones, recompensas, patronazgo jovial, oficio lucrativo y buen retorno económico. Se nota de forma directa.',
  'Lilly asocia la Parte de Fortuna dirigida al cuerpo de Júpiter con regalos, beneficios y notable aumento de fortuna por una persona grande jovial o por oficio provechoso, con éxito si el nativo sigue su vocación. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31191-31198 del fichero lilly_christian_astrology_completo.txt. Lilly agrupa aquí el cuerpo con otros aspectos de la Parte de Fortuna. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_PARTFORTUNA_SEXTIL',
  'JUPITER',
  'PARTFORTUNA',
  'SEXTIL',
  'Oportunidad moderada de Júpiter sobre Parte de Fortuna: dones, recompensas, patronazgo jovial, oficio lucrativo y buen retorno económico. Requiere cooperación consciente.',
  'Lilly asocia la Parte de Fortuna dirigida al sextil de Júpiter con regalos, beneficios y notable aumento de fortuna por una persona grande jovial o por oficio provechoso, con éxito si el nativo sigue su vocación. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31191-31198 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_PARTFORTUNA_CUADRATURA',
  'JUPITER',
  'PARTFORTUNA',
  'CUADRATURA',
  'Tensión activa de Júpiter sobre Parte de Fortuna: pérdida por nobles, clérigos, pleitos, esfuerzo defensivo y menor crecimiento de oficio. Pide actuar ante la fricción.',
  'Lilly asocia la Parte de Fortuna dirigida a la cuadratura de Júpiter con disminución de riqueza por personas gentiles o religiosas, litigios y vejaciones, mucho trabajo para conservar el estado y pérdida o menor ganancia del cargo. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31199-31204 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_PARTFORTUNA_TRIGONO',
  'JUPITER',
  'PARTFORTUNA',
  'TRIGONO',
  'Flujo favorable de Júpiter sobre Parte de Fortuna: dones, recompensas, patronazgo jovial, oficio lucrativo y buen retorno económico. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Parte de Fortuna dirigida al trígono de Júpiter con regalos, beneficios y notable aumento de fortuna por una persona grande jovial o por oficio provechoso, con éxito si el nativo sigue su vocación. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31191-31198 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'JUPITER_PARTFORTUNA_OPOSICION',
  'JUPITER',
  'PARTFORTUNA',
  'OPOSICION',
  'Confrontación externa de Júpiter sobre Parte de Fortuna: pérdida por nobles, clérigos, pleitos, esfuerzo defensivo y menor crecimiento de oficio. Se manifiesta frente a otros.',
  'Lilly asocia la Parte de Fortuna dirigida a la oposición de Júpiter con disminución de riqueza por personas gentiles o religiosas, litigios y vejaciones, mucho trabajo para conservar el estado y pérdida o menor ganancia del cargo. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Júpiter y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.738. Líneas ~31199-31204 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_PARTFORTUNA_CONJUNCION',
  'SATURNO',
  'PARTFORTUNA',
  'CONJUNCION',
  'Contacto directo de Saturno sobre Parte de Fortuna: consumo de bienes, patrimonio mermado, robo, mala gestión y retroceso económico. Se nota de forma directa.',
  'Lilly asocia la Parte de Fortuna dirigida al cuerpo de Saturno con pérdida de bienes muebles e inmuebles por rapacidad, hurto o torpeza de personas saturninas, juego con ellas y caída del estado sin causa clara. El contacto actúa de modo directo, visible y difícil de soslayar. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.737. Líneas ~31175-31180 del fichero lilly_christian_astrology_completo.txt. Lilly agrupa aquí el cuerpo con otros aspectos de la Parte de Fortuna. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_PARTFORTUNA_SEXTIL',
  'SATURNO',
  'PARTFORTUNA',
  'SEXTIL',
  'Oportunidad moderada de Saturno sobre Parte de Fortuna: aumento por ancianos, minas, agricultura, edificios, casas, mar o ganado mayor. Requiere cooperación consciente.',
  'Lilly asocia la Parte de Fortuna dirigida al sextil de Saturno con ocasión de acrecentar la hacienda por muerte de mayores, tierras, casas, minas, asuntos marítimos y trato con ancianos, bueyes o caballos. En sextil, el efecto aparece como oportunidad aprovechable si el nativo coopera. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.737-738. Líneas ~31181-31190 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_PARTFORTUNA_CUADRATURA',
  'SATURNO',
  'PARTFORTUNA',
  'CUADRATURA',
  'Tensión activa de Saturno sobre Parte de Fortuna: consumo de bienes, patrimonio mermado, robo, mala gestión y retroceso económico. Pide actuar ante la fricción.',
  'Lilly asocia la Parte de Fortuna dirigida a la cuadratura de Saturno con pérdida de bienes muebles e inmuebles por rapacidad, hurto o torpeza de personas saturninas, juego con ellas y caída del estado sin causa clara. En cuadratura, la fricción exige respuesta práctica y corrección de conducta. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.737. Líneas ~31175-31180 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_PARTFORTUNA_TRIGONO',
  'SATURNO',
  'PARTFORTUNA',
  'TRIGONO',
  'Flujo favorable de Saturno sobre Parte de Fortuna: aumento por ancianos, minas, agricultura, edificios, casas, mar o ganado mayor. Tiende a fluir con apoyo natural.',
  'Lilly asocia la Parte de Fortuna dirigida al trígono de Saturno con ocasión de acrecentar la hacienda por muerte de mayores, tierras, casas, minas, asuntos marítimos y trato con ancianos, bueyes o caballos. En trígono, el mismo significado fluye con mayor naturalidad y menor resistencia. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.737-738. Líneas ~31181-31190 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');

INSERT INTO primary_direction_meanings
  (clave, promissor, significator, aspect,
   texto_corto, texto_largo,
   fuente_nombre, fuente_referencia,
   populated, calidad)
VALUES (
  'SATURNO_PARTFORTUNA_OPOSICION',
  'SATURNO',
  'PARTFORTUNA',
  'OPOSICION',
  'Confrontación externa de Saturno sobre Parte de Fortuna: consumo de bienes, patrimonio mermado, robo, mala gestión y retroceso económico. Se manifiesta frente a otros.',
  'Lilly asocia la Parte de Fortuna dirigida a la oposición de Saturno con pérdida de bienes muebles e inmuebles por rapacidad, hurto o torpeza de personas saturninas, juego con ellas y caída del estado sin causa clara. En oposición, el asunto se exterioriza como polarización, rivalidad o disyuntiva. El juicio depende de la dignidad natal de Saturno y de la casa que rija en la natividad.',
  'William Lilly, Christian Astrology (1647)',
  '[verde] CA III, Cap. CLXV, p.737. Líneas ~31175-31180 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición en este pasaje. Síntesis propia en español.',
  1,
  7
) ON CONFLICT(clave) DO UPDATE SET
  texto_corto = excluded.texto_corto,
  texto_largo = excluded.texto_largo,
  fuente_nombre = excluded.fuente_nombre,
  fuente_referencia = excluded.fuente_referencia,
  populated = excluded.populated,
  calidad = excluded.calidad,
  updated_at = datetime('now');
