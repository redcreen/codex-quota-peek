import AppKit

final class MenuHeaderView: NSView {
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Codex Quota Peek")
    private let subtitleLabel = NSTextField(labelWithString: "--")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        frame = NSRect(x: 0, y: 0, width: 252, height: 44)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(systemSymbolName: "gauge.open.with.lines.needle.33percent", accessibilityDescription: nil)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        imageView.contentTintColor = .labelColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .labelColor

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingMiddle

        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -6),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.heightAnchor.constraint(equalToConstant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }

    func updateSubtitle(_ text: String) {
        subtitleLabel.stringValue = text
    }
}

final class MenuValueRowView: NSView {
    private let leftLabel = NSTextField(labelWithString: "--")
    private let percentLabel = NSTextField(labelWithString: "--")
    private let timeLabel = NSTextField(labelWithString: "--")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        frame = NSRect(x: 0, y: 0, width: 252, height: 30)

        for label in [leftLabel, percentLabel, timeLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.backgroundColor = .clear
        }

        leftLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        leftLabel.textColor = .labelColor

        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.alignment = .right

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .right

        addSubview(leftLabel)
        addSubview(percentLabel)
        addSubview(timeLabel)

        NSLayoutConstraint.activate([
            leftLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            leftLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            percentLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -10),
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
    }

    func update(label: String, percent: String, time: String) {
        leftLabel.stringValue = label
        percentLabel.stringValue = percent
        timeLabel.stringValue = time
    }
}

final class MenuInfoRowView: NSView {
    private let leftLabel = NSTextField(labelWithString: "--")
    private let rightLabel = NSTextField(labelWithString: "--")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        frame = NSRect(x: 0, y: 0, width: 252, height: 24)

        for label in [leftLabel, rightLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.backgroundColor = .clear
            label.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        }

        leftLabel.textColor = .secondaryLabelColor
        rightLabel.textColor = .labelColor
        rightLabel.alignment = .right
        rightLabel.lineBreakMode = .byTruncatingMiddle

        addSubview(leftLabel)
        addSubview(rightLabel)

        NSLayoutConstraint.activate([
            leftLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            leftLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            rightLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leftLabel.trailingAnchor, constant: 8),
            rightLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rightLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func update(label: String, value: String) {
        leftLabel.stringValue = label
        rightLabel.stringValue = value
    }
}

final class MenuActionRowView: NSView {
    private let button: NSButton
    private let shortcutLabel = NSTextField(labelWithString: "")

    init(title: String, shortcut: String = "", target: AnyObject?, action: Selector?) {
        self.button = NSButton(title: title, target: target, action: action)
        super.init(frame: NSRect(x: 0, y: 0, width: 252, height: 28))
        shortcutLabel.stringValue = shortcut
        setup()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func setup() {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .inline
        button.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        button.contentTintColor = .labelColor
        button.alignment = .left
        button.setButtonType(.momentaryChange)

        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.alignment = .right

        addSubview(button)
        addSubview(shortcutLabel)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            button.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -8),
            button.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcutLabel.widthAnchor.constraint(equalToConstant: 46)
        ])
    }
}

final class WeeklyPaceSelectorView: NSView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let segmentedControl = NSSegmentedControl(labels: ["40h", "56h", "70h"], trackingMode: .selectOne, target: nil, action: nil)
    private let titleWidth: CGFloat = 92
    var onSelect: ((WeeklyPacingMode) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        frame = NSRect(x: 0, y: 0, width: 320, height: 26)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLabel.textColor = .secondaryLabelColor

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.segmentStyle = .rounded
        segmentedControl.setWidth(52, forSegment: 0)
        segmentedControl.setWidth(52, forSegment: 1)
        segmentedControl.setWidth(52, forSegment: 2)
        segmentedControl.target = self
        segmentedControl.action = #selector(changeSelection(_:))

        addSubview(titleLabel)
        addSubview(segmentedControl)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: titleWidth),

            segmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            segmentedControl.centerYAnchor.constraint(equalTo: centerYAnchor),
            segmentedControl.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10)
        ])
    }

    func update(language: AppLanguage, selectedMode: WeeklyPacingMode) {
        titleLabel.stringValue = language == .english ? "Weekly work hours:" : "每周工作时长："
        let allCases = WeeklyPacingMode.allCases
        segmentedControl.selectedSegment = allCases.firstIndex(of: selectedMode) ?? 1
        for (index, mode) in allCases.enumerated() {
            segmentedControl.setLabel("\(mode.weeklyHours)h", forSegment: index)
            segmentedControl.setToolTip(nil, forSegment: index)
        }
        toolTip = nil
    }

    @objc
    private func changeSelection(_ sender: NSSegmentedControl) {
        let index = sender.selectedSegment
        guard index >= 0, index < WeeklyPacingMode.allCases.count else { return }
        onSelect?(WeeklyPacingMode.allCases[index])
    }
}
