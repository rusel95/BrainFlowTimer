//
//  TimerModel.swift
//
//  Copyright © 2016 Yalantis. All rights reserved.
//

import Foundation
import Core
import RxSwift
import RxCocoa
import RxRealm

final class TimerModel: EventNode, HasDisposeBag {
    
    var durations: Durations? {
        didSet {
            self.currentSecond.accept(durations?.work ?? 0)
        }
    }
    var currentSecond = BehaviorRelay<Int16>(value: 0)
    
    let settingsAction = PublishSubject<Void>()
    let statisticAction = PublishSubject<Void>()
    let startCountdownAction = PublishSubject<Void>()
    let pauseCountdownAction = PublishSubject<Void>()
    let stopCountdownAction = PublishSubject<Void>()
    
    private var timer = Timer()
    private var isTimerWorking = false
    
    override init(parent: EventNode) {
        super.init(parent: parent)
        
        addHandlers()
        subscribeOnSettingsChanges()
        initializeBindings()
    }
    
    private func initializeBindings() {
        
        self.durations = RealmService.shared.realm.objects(Durations.self).first
        
        settingsAction
            .doOnNext { [unowned self] _ in
                self.raise(event: MainFlowEvent.openSettings)
            }.disposed(by: disposeBag)
        
        statisticAction
            .doOnNext { [unowned self] _ in
                self.raise(event: MainFlowEvent.openStatistic)
            }.disposed(by: disposeBag)
        
        startCountdownAction
            .doOnNext { [unowned self] _ in
                self.scheduleTimer()
            }.disposed(by: disposeBag)
        
        pauseCountdownAction
            .doOnNext { [unowned self] _ in
                self.timer.invalidate()
                self.isTimerWorking = false
            }.disposed(by: disposeBag)
        
        stopCountdownAction
            .doOnNext { [unowned self] _ in
                guard let durations = self.durations else { return }
                UserDataService.removeObject(for: .savedTime)
                self.timer.invalidate()
                self.isTimerWorking = false
                self.currentSecond.accept(durations.work)
            }.disposed(by: disposeBag)
    }
    
    // MARK: - private
    
    private func pauseWhenBackround() {
        timer.invalidate()
        isTimerWorking = false
        UserDataService.set(Date(), for: .savedTime)
    }
    
    private func willEnterForeground() {
        if let savedDate = UserDataService.object(for: .savedTime) as? Date {
            let components = Calendar.current.dateComponents([.second], from: savedDate, to: Date())
            let expectedSecond = self.currentSecond.value - Int16(components.second!)
            self.currentSecond.accept(expectedSecond > 0 ? expectedSecond : 0)
            scheduleTimer()
        }
    }
    
    private func scheduleTimer() {
        if !isTimerWorking {
            guard let durations = self.durations else { return }
            isTimerWorking = true
            if self.currentSecond.value == self.durations!.work {
                SoundService.shared.playAlertSound(SoundType.startCountdown2, withVibration: true)
            }
            
            NotificationsService.shared.scheduleLocalNotification(.workIntervalFinished,
                                                                  in: UInt16(durations.work))
            
            timer = Timer.scheduledTimer(
                withTimeInterval: TimeInterval(Constants.defaultTickTimeInterval),
                repeats: true,
                block: { [weak self] (_) in
                    guard let self = self else { return }
                    self.currentSecond.accept(self.currentSecond.value - Constants.defaultTickTimeInterval)
                    SoundService.shared.playAlertSound(SoundType.clockTick1)
                    if self.currentSecond.value == 0 {
                        SoundService.shared.playAlertSound(SoundType.finish1, withVibration: true)
                        self.pauseCountdownAction.onNext(())
                    }
            })
        }
    }
    
    private func addHandlers() {
        addHandler { [unowned self] (event: ApplicationEvent) in
            switch event {
            case .applicationDidEnterBackground:
                self.pauseWhenBackround()
            case .applicationWillEnterForeground:
                self.willEnterForeground()
            }
        }
    }
    
    private func subscribeOnSettingsChanges() {
        if let durations = RealmService.shared.realm.objects(Durations.self).first {
            Observable.propertyChanges(object: durations)
                .doOnNext { [unowned self] changes in
                    if changes.name == "work", let newWorkDuration = changes.newValue as? Int16 {
                        self.currentSecond.accept(newWorkDuration)
                    }
                }.disposed(by: disposeBag)
        }
    }
}
