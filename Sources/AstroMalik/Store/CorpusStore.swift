import Foundation

// MARK: - Corpus Store
// Lee corpus.db (read-only) — sin dependencias externas, usando SQLite3 del sistema.

final class CorpusStore {
    private let db: SQLiteDB

    init(path: String) throws {
        db = try SQLiteDB(path: path, readonly: true)
    }

    // MARK: - Natal Interpretations

    func lookupNatal(claves: [String]) -> [String: Interpretation] {
        guard !claves.isEmpty else { return [:] }
        let tipos = [
            InterpretationType.natalPlanetaSigno.rawValue,
            InterpretationType.natalPlanetaCasa.rawValue,
            InterpretationType.aspectoNatal.rawValue,
        ]
        let tiposPH  = tipos.map { _ in "?" }.joined(separator: ",")
        let clavesPH = claves.map { _ in "?" }.joined(separator: ",")
        let sql = """
            SELECT clave, tipo, texto_largo, texto_corto, fuente_nombre, calidad
            FROM interpretaciones
            WHERE tipo IN (\(tiposPH)) AND clave IN (\(clavesPH))
            ORDER BY calidad DESC, LENGTH(COALESCE(texto_largo,'')) DESC
        """
        let args: [SQLiteValue] = tipos.map { .text($0) } + claves.map { .text($0) }
        var result: [String: Interpretation] = [:]
        guard let rows = try? db.query(sql, args: args) else { return result }
        for row in rows {
            guard let clave = row["clave"]?.string else { continue }
            if result[clave] != nil { continue }
            let tl = row["texto_largo"]?.string ?? ""
            let tc = row["texto_corto"]?.string ?? ""
            var texto = tl.isEmpty ? tc : tl
            texto = texto.trimmingCharacters(in: .whitespaces)
            if texto.isEmpty { continue }
            if texto.count > 4000 { texto = String(texto.prefix(3997)) + "…" }
            let tipoStr = row["tipo"]?.string ?? ""
            let tipo = InterpretationType(rawValue: tipoStr) ?? .aspectoNatal
            result[clave] = Interpretation(
                clave: clave, tipo: tipo,
                titulo: "", texto: texto,
                fuente: row["fuente_nombre"]?.string ?? "", orden: 0
            )
        }
        return result
    }

    func buildNatalInterpretations(chart: NatalChart) -> [Interpretation] {
        var claves: [String] = []
        var meta: [String: (titulo: String, tipo: InterpretationType, orden: Int)] = [:]

        for body in chart.bodies {
            let sk = AstroEngine.degToSignKey(body.longitude)
            let cSigno = "\(body.key)_\(sk)"
            let cCasa  = "\(body.key)_CASA_\(body.house)"
            let signLabel = SIGN_LABELS[body.signIndex]
            claves += [cSigno, cCasa]
            meta[cSigno] = ("\(body.label) en \(signLabel)", .natalPlanetaSigno, 1)
            meta[cCasa]  = ("\(body.label) en Casa \(body.house)", .natalPlanetaCasa, 2)
        }

        let rawPlanets = Dictionary(uniqueKeysWithValues: chart.bodies.map { b in
            (b.key, AstroEngine.RawPlanet(
                key: b.key, label: b.label,
                deg: b.longitude, speed: b.retrograde ? -1 : 1, retro: b.retrograde
            ))
        })
        let natAspects = AstroEngine.computeNatalAspects(planets: rawPlanets)
        for asp in natAspects {
            claves.append(asp.corpusClave)
            meta[asp.corpusClave] = (
                "\(asp.labelA) \(asp.aspLabel) \(asp.labelB) (orbe \(asp.orb)°)",
                .aspectoNatal, 3
            )
        }

        for pt in [("ASC", chart.ascendant.longitude), ("MC", chart.mc.longitude)] {
            for body in chart.bodies {
                var diff = abs((body.longitude - pt.1 + 360).truncatingRemainder(dividingBy: 360))
                if diff > 180 { diff = 360 - diff }
                for asp in ASPECT_DEFS {
                    let orb = abs(diff - asp.angle)
                    if orb <= asp.orb {
                        let c = "\(body.key)_\(pt.0)_\(asp.key)"
                        claves.append(c)
                        meta[c] = (
                            "\(body.label) \(asp.label) \(pt.0) (orbe \(String(format: "%.1f", orb))°)",
                            .aspectoNatal, 3
                        )
                    }
                }
            }
        }

        let textos = lookupNatal(claves: claves)
        var results: [Interpretation] = []
        for clave in claves {
            guard let corpus = textos[clave], let m = meta[clave] else { continue }
            results.append(Interpretation(
                clave: clave, tipo: m.tipo,
                titulo: m.titulo, texto: corpus.texto,
                fuente: corpus.fuente, orden: m.orden
            ))
        }
        return results.sorted {
            $0.orden != $1.orden ? $0.orden < $1.orden : $0.titulo < $1.titulo
        }
    }

    // MARK: - Transit Lookup

    func lookupTransit(trKey: String, nKey: String, aspKey: String) -> (String?, String?) {
        let clave = "\(trKey)_tr_\(nKey)_\(aspKey)"
        let sql = """
            SELECT texto_largo, texto_corto, fuente_nombre
            FROM interpretaciones
            WHERE clave = ? AND tipo = 'transito'
            ORDER BY calidad DESC, LENGTH(texto_largo) DESC LIMIT 1
        """
        guard let row = try? db.queryOne(sql, args: [.text(clave)]) else { return (nil, nil) }
        let tl = row["texto_largo"]?.string ?? ""
        let tc = row["texto_corto"]?.string ?? ""
        var texto = (tl.isEmpty ? tc : tl).trimmingCharacters(in: .whitespaces)
        if texto.isEmpty { return (nil, nil) }
        if texto.count > 3800 { texto = String(texto.prefix(3797)) + "…" }
        return (texto, row["fuente_nombre"]?.string)
    }

    func stats() -> [String: Int] {
        let sql = "SELECT tipo, COUNT(*) as n FROM interpretaciones GROUP BY tipo"
        guard let rows = try? db.query(sql) else { return [:] }
        return Dictionary(uniqueKeysWithValues: rows.compactMap { row in
            guard let tipo = row["tipo"]?.string, let n = row["n"]?.int else { return nil }
            return (tipo, n)
        })
    }
}
