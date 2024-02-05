//
//  VolumeView.swift
//  MinuteOfSilence
//
//  Created by Wladislaw Derevianko on 02.02.2024.
//

import UIKit
import MediaPlayer

// Note: I have used targetEnvironment(simulator) with the only purpose
// to make the look of the simulator screen the same as on the real device.
// Considering the fact, that MPVolumeView is not visible on simulator screen
// but the UISlider looks exactly the same.

class VolumeView: UIView {
	private(set) var isLayoutChanged = true
	var canBeShown = true
	
	func check(hideLabel: Bool) {
		var isLoud = true
		if isShowingVolume && canBeShown {
			if nil == mpSlider {
#if targetEnvironment(simulator)
				let slider = UISlider()
				slider.minimumValue = 0
				slider.maximumValue = 1
				slider.value = 0.5
#else
				let slider = MPVolumeView()
#endif
				
				mpSlider = slider
				addSubview(slider)
				isLayoutChanged = true
			}
			if let volume = slider()?.value {
				isLoud = volume > 0.6
			}
		} else if let slider = mpSlider {
			slider.removeFromSuperview()
			mpSlider = nil
			isLayoutChanged = true
		}
		lowVolumeLabel.isHidden = isLoud || hideLabel
	}
	
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		for imageView in [leftIcon, rightIcon] {
			imageView.contentMode = .scaleAspectFit
			addSubview(imageView)
		}
		lowVolumeLabel.text = String(localized: "Let's increase audio volume")
		lowVolumeLabel.font = .systemFont(ofSize: UIFont.labelFontSize)
		lowVolumeLabel.textAlignment = .center
		addSubview(lowVolumeLabel)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	// returns remaining free area (after occupying the bottom part)
	func placeAtBottom(_ rect: CGRect) -> CGRect {
		guard let mpSlider = mpSlider else {
			self.frame = CGRect(x: rect.minX, y: rect.maxY, width: rect.width, height: 0)
			return rect
		}
		let labelH = ceil(lowVolumeLabel.sizeThatFits(rect.size).height)
		let sliderHeight = mpSlider.sizeThatFits(rect.size).height
		let iconsH = round(sliderHeight * 1.2)
		let selfHeight = ceil(iconsH + labelH)
		let twoR = rect.divided(atDistance: selfHeight, from: .maxYEdge)
		self.frame = twoR.slice
		return twoR.remainder
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		guard !bounds.isEmpty, let slider = mpSlider else {
			leftIcon.frame = .null
			rightIcon.frame = .null
			lowVolumeLabel.frame = .null
			return
		}
		let sliderHeight = ceil(slider.sizeThatFits(bounds.size).height)
		let iconsH = round(sliderHeight * 1.2)
		let twoRects = bounds.divided(atDistance: iconsH, from: .maxYEdge)
		lowVolumeLabel.frame = twoRects.remainder
	
		let spacing = round(0.3 * iconsH)
		
		let leftSz = leftIcon.intrinsicContentSize
		let leftWidth = iconsH * leftSz.width / leftSz.height
		let twoR = twoRects.slice.divided(atDistance: ceil(leftWidth), from: .minXEdge)
		leftIcon.frame = twoR.slice
		
		let rightSz = rightIcon.intrinsicContentSize
		let rightWidth = iconsH * rightSz.width / rightSz.height
		let twoRRight = twoR.remainder.divided(atDistance: ceil(rightWidth), from: .maxXEdge)
		rightIcon.frame = twoRRight.slice
		
		let highRect = twoRRight.remainder.insetBy(dx: spacing, dy: 0)
		slider.frame = highRect.divided(atDistance: sliderHeight, from: .maxYEdge).slice
	}
#if targetEnvironment(simulator)
	private var mpSlider: UISlider?
#else
	private var mpSlider: MPVolumeView?
#endif
	
	private let lowVolumeLabel = UILabel()
	private let leftIcon = UIImageView(image: UIImage(systemName: "speaker.wave.1"))
	private let rightIcon = UIImageView(image: UIImage(systemName: "speaker.wave.3"))
	
	private var savedVolume: Float?
}
private extension VolumeView {
	func slider() -> UISlider? {
#if targetEnvironment(simulator)
		return mpSlider
#else
		let obj = mpSlider?.subviews.first { $0 is UISlider }
		return obj as? UISlider
#endif
	}
}

fileprivate var isShowingVolume: Bool {
	let obj = UserDefaults.standard.object(forKey: "show_volume_control")
	return (obj as? Bool) ?? true
}
