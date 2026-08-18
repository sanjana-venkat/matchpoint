import Foundation
import UIKit

/// Stable visual keys supplied by the Match Point image package.
/// Local assets with the same key automatically take priority over the CDN.
enum ImageCatalog {
    private static let remoteRoot =
        "https://d8j0ntlcm91z4.cloudfront.net/user_3Gcg7BQkFO0Y8lTHOZqv6aNw0aL/"

    static let sources: [String: String] = [
        "player.01": remoteRoot + "hf_20260818_202420_f0bc2f69-89d2-48da-9742-ea571786845b.png",
        "player.02": remoteRoot + "hf_20260818_202703_bc604cd6-4483-4e5e-847c-fecd347fcb83.png",
        "player.03": remoteRoot + "hf_20260818_202703_7aea9f28-5e3f-44d4-ab9b-c6133a8985ab.png",
        "player.04": remoteRoot + "hf_20260818_202703_44a01e7c-ab35-42e8-9ca8-b1a46d3f820e.png",
        "player.05": remoteRoot + "hf_20260818_202703_662a0339-dd0d-4e56-afe4-841066bc058f.png",
        "player.06": remoteRoot + "hf_20260818_202703_9844d165-9cec-467e-9987-44c18a9c7c5e.png",
        "player.07": remoteRoot + "hf_20260818_202703_c9031834-247d-4c33-b4c1-5149b1189f7c.png",
        "player.08": remoteRoot + "hf_20260818_202703_31b2c17c-efb2-44fd-9e06-d0d930aa3e44.png",
        "player.09": remoteRoot + "hf_20260818_202703_660fbf6b-9b61-4d08-a64c-1914e80c58c5.png",
        "player.10": remoteRoot + "hf_20260818_202703_f36a3d54-9f53-4aa8-b4cd-385f2c884ad1.png",
        "player.11": remoteRoot + "hf_20260818_202703_d794b7ba-05bf-46e1-b16e-32b86a4c28d1.png",
        "player.12": remoteRoot + "hf_20260818_202703_0b482541-9d61-4bab-a74b-8cd0a324b783.png",
        "player.13": remoteRoot + "hf_20260818_202703_19f98e1e-4571-424e-9e0d-bf969c67afb3.png",
        "player.14": remoteRoot + "hf_20260818_202746_9250abfd-8259-40ff-a8be-c17c8a0d0bb3.png",
        "player.15": remoteRoot + "hf_20260818_202746_2e7f04b1-b1f3-49d6-9cbc-f86f40912a7f.png",
        "player.16": remoteRoot + "hf_20260818_202746_75f007a4-cfbc-44a4-bdd6-2bc011712f51.png",
        "player.17": remoteRoot + "hf_20260818_202746_fa36d2d9-a3ef-4f1a-bea0-7a16b257d291.png",
        "player.18": remoteRoot + "hf_20260818_202746_189ac659-e71e-4b72-911f-992f8135e1f4.png",
        "player.19": remoteRoot + "hf_20260818_202746_f34abdfc-a984-4322-9068-4af046625b1c.png",
        "player.20": remoteRoot + "hf_20260818_202746_635d2785-674b-428f-90d4-23319e987682.png",

        "onboarding.01": remoteRoot + "hf_20260818_202419_c140dfd5-9c89-486d-bc29-6ddcffb3b722.png",
        "onboarding.02": remoteRoot + "hf_20260818_202746_83d452d3-7ab0-4655-8e93-c36002df9f69.png",
        "onboarding.03": remoteRoot + "hf_20260818_202746_d1e0535b-08a4-40f8-bd12-8d37b0bd0e99.png",

        "court.tennis": remoteRoot + "hf_20260818_202746_b88a7ff9-3df9-4197-b45a-a4520bd7b1b4.png",
        "court.badminton": remoteRoot + "hf_20260818_202746_6b8d3cd3-e017-4b67-aff2-277c257337fe.png",
        "court.basketball": remoteRoot + "hf_20260818_202746_931b443a-a39e-47c5-89e9-2a0c49673cfe.png",
        "court.pickleball": remoteRoot + "hf_20260818_202420_06d1afe5-3be4-4e0b-ac71-47ec57ce18e7.png",
        "court.padel": remoteRoot + "hf_20260818_202752_0ba35775-3a06-4371-b3b8-ff0fc774c48b.png"
    ]

    enum Resolution {
        case bundled(String)
        case remote(URL)
        case missing
    }

    static func resolve(_ key: String) -> Resolution {
        if UIImage(named: key) != nil { return .bundled(key) }
        if let source = sources[key], let url = URL(string: source) { return .remote(url) }
        return .missing
    }

    static func courtKey(for sport: Sport) -> String { "court." + sport.rawValue }

    static func playerKey(slot: Int) -> String {
        String(format: "player.%02d", min(max(slot, 1), 20))
    }
}
