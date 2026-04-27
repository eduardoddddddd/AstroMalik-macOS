-- Migración 006: Poblado del corpus clásico de Direcciones Primarias
-- Fuente principal: Lilly, Christian Astrology (1647), Libro III
--   Fichero: /horaria/fuentes/lilly_christian_astrology_completo.txt
-- Fuente complementaria: Coley, Clavis Astrologiae
-- Generado: 2026-04-28
-- Política: verde = pasaje concreto de Lilly localizado
--           amarillo = doctrina general consolidada
--           rojo = sin fuente disponible, populated=0

UPDATE primary_direction_meanings SET
    texto_corto = 'Promete favor de superiores, visibilidad y elevación moderada, aunque con ansiedad y exposición de asuntos reservados.',
    texto_largo = 'Lilly asocia el Ascendente dirigido al cuerpo del Sol con dignidad, oficio o empleo concedido por príncipes o personas de autoridad. También señala inquietud mental, publicación de asuntos secretos y posible gasto o afección de cabeza y ojos. La intensidad depende de la dignidad natal del Sol, del signo donde cae la dirección y de la concordancia con revolución y profección.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.694-695 (Effects of Directions). Líneas ~29435-29453 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'SOL_ASC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Periodo favorable para salud, reputación, amistades eminentes, viajes honrosos y empleos provechosos.',
    texto_largo = 'Para el Ascendente al sextil o trígono del Sol, Lilly describe salud corporal, tranquilidad de ánimo, incremento de bienes y reputación, junto con amigos de gran cuenta, viajes o empleos honorables y útiles. No separa sextil y trígono, por lo que se conserva la misma doctrina. La intensidad depende de la dignidad natal del Sol y del signo donde cae la dirección.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.695 (Effects of Directions). Líneas ~29454-29459 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono; síntesis en español.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'SOL_ASC_SEXTIL';

UPDATE primary_direction_meanings SET
    texto_corto = 'Tensión con autoridades, pérdidas, pleitos y afecciones coléricas, sobre todo en ojos y estado general.',
    texto_largo = 'Lilly atribuye al Ascendente dirigido a la cuadratura u oposición del Sol descontento de príncipes o magistrados, pérdidas, engaños, decadencia de bienes, dolores de ojos y enfermedades coléricas. Advierte que la cuadratura suele mostrar menos gravedad que la oposición. La intensidad depende de la dignidad natal del Sol, del signo y de otros testimonios del año.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.695 (Effects of Directions). Líneas ~29460-29472 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición, distinguiendo mayor severidad en la oposición.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'SOL_ASC_CUADRATURA';

UPDATE primary_direction_meanings SET
    texto_corto = 'Periodo favorable para salud, reputación, amistades eminentes, viajes honrosos y empleos provechosos.',
    texto_largo = 'Para el Ascendente al sextil o trígono del Sol, Lilly describe salud corporal, tranquilidad de ánimo, incremento de bienes y reputación, junto con amigos de gran cuenta, viajes o empleos honorables y útiles. No separa sextil y trígono, por lo que se conserva la misma doctrina. La intensidad depende de la dignidad natal del Sol y del signo donde cae la dirección.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.695 (Effects of Directions). Líneas ~29454-29459 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono; síntesis en español.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'SOL_ASC_TRIGONO';

UPDATE primary_direction_meanings SET
    texto_corto = 'Año áspero de autoridad contrariada, pleitos, gastos, daño de reputación y riesgo de encierro o viaje adverso.',
    texto_largo = 'En el mal aspecto del Ascendente al Sol, Lilly menciona oposición de magistrados o grandes hombres, pérdidas, pleitos, enfermedades coléricas y daño en los ojos. Para la oposición agrava el juicio: prisión, perjuicio por viajes marítimos o empresas de personas poderosas y notable consumo de bienes. La intensidad depende de la dignidad natal del Sol y de los apoyos de fortuna.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.695 (Effects of Directions). Líneas ~29460-29472 del fichero lilly_christian_astrology_completo.txt. Lilly trata cuadratura y oposición, indicando mayor severidad para la oposición.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'SOL_ASC_OPOSICION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Tiempo mutable: negocio, mujeres, viajes o matrimonio, con salud sensible si la Luna radical está débil.',
    texto_largo = 'Lilly indica que el Ascendente dirigido al cuerpo de la Luna puede enriquecer o empobrecer con rapidez según la condición lunar. Si la Luna está fortificada, favorece prosperidad, salud y gestión de asuntos; si está afligida, trae accidentes, peligros cerca del agua, cólicos u otros males lunares. La intensidad depende de la dignidad natal de la Luna y del signo de la dirección.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.697-698 (Effects of Directions). Líneas ~29573-29595 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'LUNA_ASC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Controversias con madre, esposa o mujeres, inquietud, humores corruptos, peligro por agua y pérdida de favor.',
    texto_largo = 'Para el Ascendente a la cuadratura u oposición de la Luna, Lilly describe discordia con madre, esposa o mujeres, celos, afrentas de gente ruda, abundancia de humores viciosos, peligro por agua y dolor del ojo izquierdo. También señala fracaso en viajes o navegación, pérdida de preferencia y dieta desordenada. La intensidad depende de la Luna natal y del signo.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.698 (Effects of Directions). Líneas ~29604-29616 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición; síntesis en español.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'LUNA_ASC_CUADRATURA';

UPDATE primary_direction_meanings SET
    texto_corto = 'Año marcial: cólera, disputas, accidentes, heridas, fiebre aguda y peligro por hierro, fuego o viajes.',
    texto_largo = 'Lilly presenta el Ascendente dirigido al cuerpo de Marte como inclinación a cólera, disputas, litigios, duelos y peligros en viaje. Señala heridas por caballos, hierro, fuego, armas o disparos, fiebre violenta, viruela o pestilencia si el contexto lo permite. La intensidad depende de la dignidad natal de Marte, del signo y de si actúan fortunas mitigadoras.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.693 (Effects of Directions). Líneas ~29372-29388 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'MARTE_ASC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Dirección tensa de fiebre, accidentes súbitos, heridas, enemigos, gastos y necesidad de evitar conflicto.',
    texto_largo = 'En el Ascendente a la cuadratura u oposición de Marte, Lilly habla de fiebre aguda por sobrecalentamiento de la sangre, cólera abundante, infortunios súbitos, heridas, quemaduras, caídas, grandes gastos y enemigos o acusaciones. Recomienda evitar conflictos e instrumentos marciales. La intensidad depende de la dignidad de Marte y del elemento del signo donde opera.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.694 (Effects of Directions). Líneas ~29400-29428 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición; síntesis en español.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'MARTE_ASC_CUADRATURA';

UPDATE primary_direction_meanings SET
    texto_corto = 'Período de enfermedades frías y secas, languidez corporal, melancolía y estancamiento general.',
    texto_largo = 'Lilly asocia el Ascendente dirigido al cuerpo de Saturno con mala disposición corporal, enfermedades frías y secas o exceso de flema: tos, fiebres largas, vértigos, perturbaciones de la mente, imaginaciones sombrías, consunción y lentitud. En signos de agua añade peligro por agua. La intensidad depende de la dignidad natal de Saturno y del signo donde cae la dirección.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.690 (Effects of Directions). Líneas ~29238-29251 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'SATURNO_ASC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Año pesado de dolencias crónicas, tristeza, retrasos, pleitos con mayores y daño de oficio o reputación.',
    texto_largo = 'Lilly llama terrible al Ascendente dirigido a la cuadratura u oposición de Saturno cuando otros testimonios lo refuerzan. Describe enfermedades frías, largas y recurrentes, cólicos, gota, fístulas, tumores, dolores, año triste y lleno de descontentos, retraso de acciones, pérdida de oficio, fama o buen nombre. La intensidad depende de Saturno natal y del signo.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.691 (Effects of Directions). Líneas ~29277-29288 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición; síntesis en español.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'SATURNO_ASC_CUADRATURA';

UPDATE primary_direction_meanings SET
    texto_corto = 'Año saludable y próspero, con alegría, patronazgo de personas eminentes, crédito y posible matrimonio.',
    texto_largo = 'Lilly atribuye al Ascendente dirigido al cuerpo de Júpiter constitución sana, ánimo alegre, trato con hombres buenos y religiosos, aumento de fortuna por dones o patronazgo de personas eminentes, estimación y éxito general. Puede indicar matrimonio o grado eclesiástico si edad y condición lo permiten. La intensidad depende de la fortaleza natal de Júpiter y de la casa que rige.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLIX, p.691-692 (Effects of Directions). Líneas ~29299-29330 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'JUPITER_ASC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Incremento de fortuna, amistad, honor, tranquilidad mental, salud y favor de nobles o clérigos.',
    texto_largo = 'Para el Ascendente al sextil o trígono de Júpiter, Lilly promete aumento de fortuna, patrimonio, amistad, honor y gloria en las acciones del año, con tranquilidad de ánimo y cuerpo sano. Añade favor de príncipes, nobles, caballeros o eclesiásticos, empleo honorable o viaje provechoso. La intensidad depende de la dignidad natal de Júpiter y del signo.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLIX, p.692 (Effects of Directions). Líneas ~29331-29345 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos sextil y trígono; síntesis en español.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'JUPITER_ASC_TRIGONO';

UPDATE primary_direction_meanings SET
    texto_corto = 'Contento corporal y anímico, agrado de mujeres, adornos, placer, posible boda o nacimiento si el radix lo permite.',
    texto_largo = 'Lilly describe el Ascendente dirigido al cuerpo de Venus como tiempo de contento en cuerpo y mente, aceptación por mujeres, galantería, vestidos, joyas y asuntos domésticos agradables. Si la edad y el estado lo permiten, puede señalar matrimonio o nacimiento de un hijo; si Venus está mal dispuesta, exceso sensual o enfermedad venérea. La intensidad depende de Venus natal.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.695-696 (Effects of Directions). Líneas ~29474-29498 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'VENUS_ASC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Activa estudio, escritura, comercio, cuentas y oficios útiles; favorece viajes y trato con escribanos.',
    texto_largo = 'Lilly asocia el Ascendente dirigido al cuerpo de Mercurio con estudio, poesía, matemáticas, letras y ganancia por esas materias. Promete oficio o empleo de cuenta, fortuna en comercio, profesión o manufactura, viajes y mucha ocupación con cuentas, leyes, escribanos o abogados. La intensidad depende de la dignidad natal de Mercurio y del signo de la dirección.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLVIII, p.696-697 (Effects of Directions). Líneas ~29523-29541 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'MERCURIO_ASC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Elevación pública, fama y favor de autoridades; puede traer dignidad, encargo visible o acceso a poder.',
    texto_largo = 'Lilly dice que el Medio Cielo dirigido al cuerpo del Sol prefiere al nativo a dignidad y honor, lo hace conocido y aceptado por reyes, nobles y personas de mando. Sus asuntos se desempeñan con fidelidad y sabiduría, recibiendo favor público; en genituras reales puede indicar acceso al reino. La intensidad depende del Sol natal y del estado del MC.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLX, p.706 (Effects of Directions). Líneas ~29896-29909 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'SOL_MC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Pérdida o amenaza de oficio, descrédito ante grandes hombres, caída de fortuna y peligro por orgullo.',
    texto_largo = 'Para el Medio Cielo a la cuadratura u oposición del Sol, Lilly señala discomodidades, odio de grandes hombres, pérdida súbita de oficios, honores o preferencias y cambio de fortunas anteriores. Puede implicar prisión, destierro o sentencia si la natividad lo permite; los padres participan de la infelicidad. La intensidad depende de la fuerza del Sol y de la revolución.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLX, p.706-707 (Effects of Directions). Líneas ~29922-29968 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición; síntesis en español.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'SOL_MC_CUADRATURA';

UPDATE primary_direction_meanings SET
    texto_corto = 'Tiempo público variable: negocios, viajes, matrimonio o preferencia, según la dignidad lunar radical.',
    texto_largo = 'Lilly interpreta el Medio Cielo dirigido al cuerpo de la Luna como época inquieta y ocupada, con pérdidas y ganancias alternas. Si la Luna está bien dignificada, puede traer gran comercio, preferencia, oficio o dignidad; también inclinación a viajar y mostrarse en público, y a veces matrimonio o amistad estrecha con una mujer. La intensidad depende de la Luna natal.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLX, p.709-710 (Effects of Directions). Líneas ~30069-30081 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'LUNA_MC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Crisis pública marcial: ira de poderosos, prisión, exilio, consumo patrimonial y conflictos armados.',
    texto_largo = 'Lilly describe el Medio Cielo dirigido al cuerpo de Marte como irrupción de grandes infortunios de vida y fortuna, con males surgidos de modo inesperado. Despierta la ira de hombres poderosos, en especial marciales, amenaza destierro, prisión, odio y consumo del patrimonio por fuego, robo u otras violencias. La intensidad depende de Marte natal y del signo.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLX, p.705 (Effects of Directions). Líneas ~29853-29865 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'MARTE_MC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Desfavor de magistrados o grandes hombres, pérdida de honra, cargos o confianza, y acción lenta o torpe.',
    texto_largo = 'Lilly dice que el Medio Cielo dirigido al cuerpo de Saturno despierta ira de príncipes, magistrados, oficiales y grandes hombres contra el nativo. Subvierte honores, mandos, favores y oficios de confianza; induce acciones remisas o indignas y, en cartas que prometen muerte violenta, puede indicar sentencia de juez. La intensidad depende de Saturno natal y del MC.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLX, p.702-703 (Effects of Directions). Líneas ~29762-29776 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'SATURNO_MC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Año honorable y provechoso: promoción, dignidad, patronazgo de personas grandes y aumento de riqueza.',
    texto_largo = 'Lilly considera el Medio Cielo dirigido al cuerpo de Júpiter un año saludable, provechoso y glorioso. Promete preferencia a dignidad y honor por favor, generosidad o patronazgo de persona grande, a menudo clérigo o jurista; da avance según la capacidad del nativo, desde oficio modesto hasta altos honores. La intensidad depende de Júpiter natal.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLX, p.703-704 (Effects of Directions). Líneas ~29806-29822 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'JUPITER_MC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Alegría pública, favor de mujeres, buena recepción popular, comercio grato y posible matrimonio o preferencia.',
    texto_largo = 'Lilly asigna al Medio Cielo dirigido al cuerpo de Venus alegría de ánimo, mirth, banquetes y trato con mujeres jóvenes; si la edad lo permite, matrimonio o gran honor y amistad por mujeres. También promete buen comercio, retorno para mercaderes, amor del pueblo y aceptación de los esfuerzos del nativo por su príncipe. La intensidad depende de Venus natal.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLX, p.707 (Effects of Directions). Líneas ~29969-29978 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'VENUS_MC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Promueve honores por estudio, escritura, cuentas, comercio y diligencia; trae mucha actividad pública.',
    texto_largo = 'Lilly afirma que el Medio Cielo dirigido al cuerpo de Mercurio fortuna el despacho de negocios generales y da preferencia u honor por aprendizaje, escritura, números, cuentas, astronomía, astrología o geometría. Aumenta patrimonio y reputación por industria y sabiduría, aunque Mercurio puede deprimir súbitamente por escándalo o falsa información si está mal dispuesto.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLX, p.708 (Effects of Directions). Líneas ~30017-30029 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'MERCURIO_MC_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'La Luna al Sol mezcla fiebre, revelación de secretos, cambio de estado, ojos sensibles y posible matrimonio.',
    texto_largo = 'Lilly indica que la Luna dirigida al cuerpo del Sol causa fiebres ardientes, revela secretos antes ocultos y vuelve mutable la condición del nativo, a veces elevado y luego detenido. Puede debilitar los ojos; en cartas de príncipes da honra del padre o acceso a poder, y en cartas comunes puede indicar matrimonio. La intensidad depende del Sol natal, de la Luna y del signo.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLXIV, p.730 (Effects of Directions). Líneas ~30880-30894 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'SOL_LUNA_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Año contencioso, con oposición de superiores, fiebre, ojos sensibles, viajes malos y tensión pública.',
    texto_largo = 'En la Luna a la cuadratura u oposición del Sol, Lilly habla de peligros extremos y tormentos de cuerpo y mente, ira, pérdida de favor femenino, tumultos populares y amistades nobles disimuladas que consumen bienes. Añade enfermedades de ojos, fiebres violentas, cólicos, flujos y fuerte oposición de superiores. La intensidad depende del signo y de la fortaleza de ambos luminares.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLXIV, p.731 (Effects of Directions). Líneas ~30915-30938 del fichero lilly_christian_astrology_completo.txt. Lilly trata juntos cuadratura y oposición; síntesis en español.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'SOL_LUNA_CUADRATURA';

UPDATE primary_direction_meanings SET
    texto_corto = 'Crisis de oposición lunar-solar: desorden corporal y mental, superiores adversos y riesgo público severo.',
    texto_largo = 'Lilly valora poco la cuadratura frente a la oposición de la Luna al Sol y describe para el mal aspecto un año problemático y contencioso, con oposición de grandes personas, fiebres extremas, cólicos, flujos y enfermedades de ojos si el lugar zodiacal lo indica. En cartas que prometen caída o muerte violenta, la oposición puede activar el desenlace. La intensidad depende del radix.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLXIV, p.731 (Effects of Directions). Líneas ~30915-30938 del fichero lilly_christian_astrology_completo.txt. Lilly trata cuadratura y oposición, dando mayor peso a la oposición.',
    populated = 1,
    calidad = 7,
    updated_at = datetime('now')
WHERE clave = 'SOL_LUNA_OPOSICION';

UPDATE primary_direction_meanings SET
    texto_corto = 'La Luna a Marte trae prisión o ansiedad, heridas, fiebre aguda, cólera, disputas y peligro por fuego o hierro.',
    texto_largo = 'Lilly atribuye a la Luna dirigida al cuerpo de Marte prisión, muchos infortunios mundanos, ansiedades, tristezas y pérdida de bienes. Señala fiebre aguda, debilidad, peligro de vida, ojos debilitados, males en partes secretas, heridas por hierro o arma, peligro por fuego o animales y fuerte inclinación a pelear. La intensidad depende de Marte natal y del signo.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLXIV, p.728 (Effects of Directions). Líneas ~30808-30825 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'MARTE_LUNA_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Dolencias frías y húmedas, melancolía, pleitos con autoridad, pérdidas por servidores y angustia mental.',
    texto_largo = 'Lilly describe la Luna dirigida al cuerpo de Saturno como productora de enfermedades frías y húmedas: apoplejía, parálisis, hidropesía, gota, fiebres melancólicas o flemáticas, tos extrema y debilidad. Añade contiendas con magistrados o nobles por calumnias, daños por criados, muerte de ganado, tristeza y defecto general de amistades. La intensidad depende de Saturno natal.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLXIV, p.725-726 (Effects of Directions). Líneas ~30708-30728 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'SATURNO_LUNA_CONJUNCION';

UPDATE primary_direction_meanings SET
    texto_corto = 'Salud, honor y riqueza; viajes prósperos, alegría, mando u oficio y favor de juristas o clérigos.',
    texto_largo = 'Para la Luna dirigida al cuerpo de Júpiter, Lilly señala salud corporal, gran honor acompañado de riqueza, daño para adversarios, viajes prósperos y tranquilidad de ánimo. Puede dar dominio, oficio o mando sobre el pueblo, grados universitarios o en Inns of Court; en príncipes, concordia con súbditos y embajadas útiles. La intensidad depende de Júpiter natal.',
    fuente_nombre = 'William Lilly, Christian Astrology (1647)',
    fuente_referencia = '[verde] CA III, Cap. CLXIV, p.727 (Effects of Directions). Líneas ~30765-30776 del fichero lilly_christian_astrology_completo.txt. Síntesis en español de la doctrina original en inglés.',
    populated = 1,
    calidad = 8,
    updated_at = datetime('now')
WHERE clave = 'JUPITER_LUNA_CONJUNCION';
