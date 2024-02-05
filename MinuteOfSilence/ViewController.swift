//
//  ViewController.swift
//  MinuteOfSilence
//
//  Created by Wladislaw Derevianko on 06.01.2024.
//

import UIKit
import Combine

class ViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.
		bellImage.contentMode = .scaleAspectFit
		bellImage.image = UIImage(named: "AppIcon")
		view.addSubview(bellImage)
		bellImage.isHidden = true
		
		titleLabel.textColor = UIColor(named: "titleColor")
		titleLabel.textAlignment = .center
		titleLabel.numberOfLines = 0
		view.addSubview(titleLabel)
		
		timeLabel.textColor = UIColor(named: "timeColor")
		timeLabel.textAlignment = .center
		timeLabel.numberOfLines = 0
		view.addSubview(timeLabel)
		
		view.addSubview(volumeView)
	}
	deinit {
		stopSound()
		timer?.invalidate()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
	
		updateUI(force: true)
		timer?.invalidate()
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
			self?.updateUI(force: false)
		})
		timer?.tolerance = 0.1
		
		errorPublisher.receive(on: DispatchQueue.main).sink
		{ [weak self] error in
			let title = String(localized: "Error")
			let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
			alert.addAction(UIAlertAction(title: "OK", style: .cancel))
			self?.present(alert, animated: true)
		}.store(in: &cancellableSet)
		
		updateUI(force: false)
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let area = view.bounds.inset(by: view.safeAreaInsets)
		let innerArea = area.insetBy(dx: round(area.width / 20), dy: 0)
		
		let showsImage = !bellImage.isHidden
		
		let smallerSide = min(area.width, area.height)
		let fontSize1 = UIFont.labelFontSize
		let fontSz1 = max(fontSize1, round(smallerSide / 13))
		titleLabel.font = .systemFont(ofSize: fontSz1)
		
		let timeFontSizeFraction = (showsImage ? 4.0 : 25.0)
		let fontSz2 = max(fontSize1, round(smallerSide / timeFontSizeFraction))
		timeLabel.font = .systemFont(ofSize: fontSz2)
		
		let contentArea = volumeView.placeAtBottom(innerArea)
		
		let h1 = ceil(titleLabel.sizeThatFits(innerArea.size).height)
		let h2 = ceil(timeLabel.sizeThatFits(innerArea.size).height)
		let spacing = round(smallerSide / 30)
		if showsImage {
			let timeRect = CGRect(x: contentArea.minX, y: contentArea.maxY - h2,
								  width: contentArea.width, height: h2)
			timeLabel.frame = timeRect
			let imageHeight = max(spacing, min(contentArea.width, timeRect.minY - contentArea.minY - spacing))
			bellImage.frame = CGRect(x: contentArea.minX, y: contentArea.minY, width: contentArea.width, height: imageHeight)
		} else {
			let minY = round(contentArea.midY - 0.5 * (h1 + spacing + h2))
			let rect1 = CGRect(x: contentArea.minX, y: minY, width: contentArea.width, height: h1)
			titleLabel.frame = rect1
			let rect2 = CGRect(x: contentArea.minX, y: rect1.maxY + spacing, width: contentArea.width, height: h2)
			timeLabel.frame = rect2
		}
		
	}

	let bellImage = UIImageView()
	let titleLabel = UILabel()
	let timeLabel = UILabel()
	let volumeView = VolumeView()
	
	
	let calendar = getUkrainianCalendar()
	var timer: Timer?
	var bangTimer: Timer?
	var prevNumericalHourMinute = -1
	var isIdleTimerDisabled = false
	var isExpectingDeclaration = false
	var isAudioEngaged = false
	
	var cancellableSet = Set<AnyCancellable>()
}
private extension ViewController {
	func updateUI(force: Bool) {
		let components = calendar.dateComponents([.hour, .minute, .second], from: Date())
		guard	let hour = components.hour,
				let minutes = components.minute,
				let seconds = components.second
		else {
			fatalError("Cannot parse time to hours and minutes")
		}
		
		var shouldPlay = false
		
		// the integer number that in decimal representation looks like "hhmm"
		let numericalHourMinute = 100 * hour + minutes
		if prevNumericalHourMinute < 0 {
			// first time is running, skip declaration if it is too late
			isExpectingDeclaration = (numericalHourMinute < 855) // new launch of the app
		} else if !isExpectingDeclaration && numericalHourMinute < 855 {
			isExpectingDeclaration = true	// the time wraps to zero after midnight
		}
		let timeString = getTimeString(hour: hour, minutes: minutes)
		var needsLayout = false
		var showLabels = true
		var canShowVolumeControl = false
		if numericalHourMinute < 850 {
			if force || prevNumericalHourMinute < 0 || prevNumericalHourMinute >= 850 {
				titleLabel.text = String(localized: "The event will begin today at 9:00 Kyiv time")
				needsLayout = true
			}
			if force || (numericalHourMinute != prevNumericalHourMinute) {
				timeLabel.text = String(localized: "current time") + " " + timeString
				needsLayout = true
			}
			if isIdleTimerDisabled {
				isIdleTimerDisabled = false
				UIApplication.shared.isIdleTimerDisabled = false
			}
		} else if numericalHourMinute < 900 {
			canShowVolumeControl = true
			titleLabel.text = String(localized: "Seconds to start:")
			let secondsLeft = 3600 - ((60 * minutes) + seconds)
			timeLabel.text = String(secondsLeft)
			if secondsLeft <= 7 && isExpectingDeclaration {
				playDeclaration()
				isExpectingDeclaration = false
			}
			if !isIdleTimerDisabled {
				isIdleTimerDisabled = true
				UIApplication.shared.isIdleTimerDisabled = true
			}
		} else if numericalHourMinute < 901 {
			canShowVolumeControl = true
			shouldPlay = true
			showLabels = false
			needsLayout = true
			timeLabel.text = String(seconds)
		} else {
			canShowVolumeControl = (numericalHourMinute < 902)
			if force || prevNumericalHourMinute < 901 {
				titleLabel.text = String(localized: "The event did occur today at 9:00 Kyiv time")
				needsLayout = true
			}
			if force || (numericalHourMinute != prevNumericalHourMinute) {
				timeLabel.text = String(localized: "current time") + " " + timeString
				needsLayout = true
			}
			if isIdleTimerDisabled {
				isIdleTimerDisabled = false
				UIApplication.shared.isIdleTimerDisabled = false
			}
		}
		bellImage.isHidden = showLabels
		titleLabel.isHidden = !showLabels
		volumeView.canBeShown = canShowVolumeControl
		volumeView.check(hideLabel: (numericalHourMinute >= 901))
		if (needsLayout || prevNumericalHourMinute < 0 || volumeView.isLayoutChanged) {
			view.setNeedsLayout()
		}
		if !isAudioEngaged && UIApplication.shared.applicationState == .active {
			isAudioEngaged = startSound()
		}
		
		prevNumericalHourMinute = numericalHourMinute
		
		if shouldPlay {
			if nil == bangTimer {
				let tm = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
					playSoundBuffer()
				}
				tm.tolerance = 0.1
				bangTimer = tm
				playSoundBuffer()
			}
		} else if let tm = bangTimer {
			tm.invalidate()
			bangTimer = nil
		}
	}
}

fileprivate func getUkrainianCalendar() -> Calendar {
	let array = TimeZone.knownTimeZoneIdentifiers
	let wordsToSearch = ["Europe/Kyiv", "Europe/Kiev"]
	let kyivIdentifier = wordsToSearch.first { array.contains($0) }

	guard let kyivIdentifier = kyivIdentifier,
		  let kyivTimeZone = TimeZone(identifier: kyivIdentifier)
	else {
		fatalError("Cannot find Ukrainian time zone!")
	}
	
	var calendar = Calendar(identifier: .gregorian)
	calendar.timeZone = kyivTimeZone
	return calendar
}
fileprivate func getTimeString(hour: Int, minutes: Int) -> String {
	let formatter = NumberFormatter()
	formatter.minimumIntegerDigits = 2
	if let minuteString = formatter.string(from: minutes as NSNumber) {
		return "\(hour):\(minuteString)"
	}
	fatalError("cannot format time string")
}

