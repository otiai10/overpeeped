import XCTest
@testable import Overpeeped

final class MascotModelTests: XCTestCase {
    // MARK: - Registry
    func testRegistryResolvesKnownModels() {
        XCTAssertEqual(MascotRegistry.model(id: "chick").id, "chick")
        XCTAssertEqual(MascotRegistry.model(id: "lizard").id, "lizard")
    }

    /// nil / 未知 ID は既定の chick にフォールバックする
    func testRegistryFallsBackToChick() {
        XCTAssertEqual(MascotRegistry.defaultID, "chick")
        XCTAssertEqual(MascotRegistry.model(id: nil).id, "chick")
        XCTAssertEqual(MascotRegistry.model(id: "no-such-model").id, "chick")
    }

    // MARK: - Frames
    /// 全 model・全 Emotion でフレームが空でないこと (空配列は描画不能)。
    /// 併せて DEBUG ビルドでは art() 内の 16×16 グリッド assert が走る。
    func testEveryModelHasFramesForEveryEmotion() {
        for model in MascotRegistry.all {
            for emotion in Emotion.allCases {
                XCTAssertFalse(model.frames(for: emotion).isEmpty,
                               "\(model.id) は \(emotion) のフレームを持つべき")
            }
        }
    }

    func testFrameDurationsArePositive() {
        for model in MascotRegistry.all {
            for emotion in Emotion.allCases {
                XCTAssertGreaterThan(model.frameDuration(for: emotion), 0,
                                     "\(model.id) \(emotion) の frameDuration は正のはず")
            }
        }
    }

    // MARK: - Cry
    /// thinking / focused / sulking は無音、それ以外は creature 固有の鳴き声を返す。
    func testCryVocalAndSilentEmotions() {
        let silent: Set<Emotion> = [.thinking, .focused, .sulking]
        for model in MascotRegistry.all {
            for emotion in Emotion.allCases {
                if silent.contains(emotion) {
                    XCTAssertNil(model.cry(for: emotion),
                                 "\(model.id) \(emotion) は無音のはず")
                } else {
                    XCTAssertNotNil(model.cry(for: emotion),
                                    "\(model.id) \(emotion) は鳴くはず")
                }
            }
        }
    }

    /// chick と lizard は別の鳴き声を持つ (model ごとに voice が違う)。
    func testModelsHaveDistinctCries() {
        XCTAssertEqual(ChickModel().cry(for: .happy), "ぴよっ♪")
        XCTAssertEqual(LizardModel().cry(for: .happy), "ちろっ♪")
        XCTAssertNotEqual(ChickModel().cry(for: .angry), LizardModel().cry(for: .angry))
    }
}
