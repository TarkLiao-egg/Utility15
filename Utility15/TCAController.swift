import UIKit
import ComposableArchitecture
import SnapKit
import Combine

struct AnyFactClient {
    var fetch: (Any?) async throws -> String
}

extension AnyFactClient: DependencyKey {
    
    static let liveValue = Self(
        fetch: { obj in
            return "Test"
        }
    )
}

extension DependencyValues {
    var anyAction: AnyFactClient {
        get {self[AnyFactClient.self]}
        set {self[AnyFactClient.self] = newValue}
    }
}
struct Feature: ReducerProtocol {
    let numberFact: (Int) async throws -> String
    @Dependency(\.anyAction) var anyAction
    struct State: Equatable {
        var count = 0
        var numberFactAlert: String?
    }
    enum Action: Equatable {
        case factAlertDismissed
        case decrementButtonTapped
        case incrementButtonTapped
        case numberFactButtonTapped
        case numberFactResponse(TaskResult<String>)
    }
    func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
        switch action {
          case .factAlertDismissed:
            state.numberFactAlert = nil
            return .none

          case .decrementButtonTapped:
            state.count -= 1
            return .none

          case .incrementButtonTapped:
            state.count += 1
            return .none

          case .numberFactButtonTapped:
            return .task { [count = state.count] in
              await .numberFactResponse(
                
                TaskResult {
                    try await self.anyAction.fetch(count)
//                    try await self.numberFact(count)
                }
              )
            }

          case let .numberFactResponse(.success(fact)):
            state.numberFactAlert = fact
            return .none

          case .numberFactResponse(.failure):
            state.numberFactAlert = "Could not load a number fact :("
            return .none
        }
      }
}

class TCAController: UIViewController {
    let store = StoreOf<Feature>(initialState: Feature.State(), reducer: Feature(numberFact: { num in
        let (data, _) = try await URLSession.shared.data(from: .init(string: "http://numbersapi.com/\(num)")!)
        return String(decoding: data, as: UTF8.self)
    }))
    
    var bindArray = Set<AnyCancellable>()
    let label = UILabel()
    let dBtn = UIButton()
    let iBtn = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.text = "0"
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        dBtn.setTitle("Decrement", for: .normal)
        dBtn.addTarget(self, action: #selector(decrementTapped), for: .touchUpInside)
        view.addSubview(dBtn)
        dBtn.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        iBtn.setTitle("increment", for: .normal)
        iBtn.addTarget(self, action: #selector(incrementTapped), for: .touchUpInside)
        view.addSubview(iBtn)
        iBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        ViewStore(store).publisher.sink { [unowned self] state in
            label.text = String(state.count)
        }.store(in: &bindArray)
    }

    @IBAction func decrementTapped() {
        test()
//        ViewStore(store).send(.decrementButtonTapped)
    }

    @IBAction func incrementTapped() {
        ViewStore(store).send(.incrementButtonTapped)
    }
    
    func test() {
        
        let store = TestStore(initialState: Feature.State(), reducer: Feature(numberFact: { "\($0) is a good number Brent" }))
        Task {
            await store.send(.incrementButtonTapped) {
                $0.count = 1 //trigger error when fail
                print($0)
            }
            
            await store.send(.numberFactButtonTapped)
            await store.receive(.numberFactResponse(.success("Test"))) {
                $0.numberFactAlert = "Test"
            }
        }
    }
}
