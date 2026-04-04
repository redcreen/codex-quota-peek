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
