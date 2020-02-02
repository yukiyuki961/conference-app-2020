import ios_combined
import RxCocoa
import RxSwift

final class SessionViewModel {
    private let disposeBag = DisposeBag()

    // input
    private let toggleEmbeddedViewRelay = PublishRelay<Void>()
    private let remoteSessionsRelay: BehaviorRelay<[Session]> = .init(value: [])
    private let localSessionsRelay: BehaviorRelay<[AppBaseSession]> = .init(value: [])

    func toggleEmbeddedView() {
        toggleEmbeddedViewRelay.accept(())
    }

    // output
    let isFocusedOnEmbeddedView: Driver<Bool>
    let sessions: Observable<[AppBaseSession]>

    // dependencies
    private let bookingSessionProvider: BookingSessionProvider = .init()

    init() {
        let isFocusedOnEmbeddedViewRelay = BehaviorRelay<Bool>(value: true)
        isFocusedOnEmbeddedView = isFocusedOnEmbeddedViewRelay.asDriver()

        sessions = Observable.combineLatest(
            remoteSessionsRelay
                .asObservable()
                .map { sessions in
                    sessions.compactMap { (session) -> AppBaseSession? in
                        if let session = session as? SpeechSession {
                            return AppSpeechSession(session: session)
                        } else if let session = session as? ServiceSession {
                            return AppServiceSession(session: session)
                        }
                        return nil
                    }
                },
            localSessionsRelay
                .asObservable()
        ).map { (arg: ([AppBaseSession], [AppBaseSession])) -> [AppBaseSession] in
            var (remote, local) = arg
            remote.removeAll(where: { session in
                local.map { $0.id?.id }.contains(session.id?.id)
            })
            remote.append(contentsOf: local)
            remote.sort(by: { $0.startTime < $1.startTime })
            return remote
        }

        let dataProvider = SessionDataProvider()

        dataProvider
            .fetchSessions()
            .asObservable()
            .bind(to: remoteSessionsRelay)
            .disposed(by: disposeBag)

        bookingSessionProvider
            .fetchBookedSessions()
            .bind(to: localSessionsRelay)
            .disposed(by: disposeBag)

        toggleEmbeddedViewRelay.asObservable()
            .withLatestFrom(isFocusedOnEmbeddedViewRelay)
            .map { !$0 }
            .bind(to: isFocusedOnEmbeddedViewRelay)
            .disposed(by: disposeBag)
    }

    func bookSession(_ session: AppBaseSession) -> Observable<Void> {
        return bookingSessionProvider.bookSession(session: session).asObservable()
    }

    func resignBookingSession(_ session: AppBaseSession) -> Observable<Void> {
        return bookingSessionProvider.resignBookingSession(session).asObservable()
    }
}
