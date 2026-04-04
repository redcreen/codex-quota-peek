import AppKit

final class MenuHeaderView: NSView {
    private let imageView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Codex Quota Peek")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        frame = NSRect(x: 0, y: 0, width: 260, height: 34)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(systemSymbolName: "gauge.open.with.lines.needle.33percent", accessibilityDescription: nil)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        imageView.contentTintColor = .labelColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor

        addSubview(imageView)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 18),
            imageView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
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
        frame = NSRect(x: 0, y: 0, width: 260, height: 34)

        for label in [leftLabel, percentLabel, timeLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.backgroundColor = .clear
        }

        leftLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        leftLabel.textColor = .labelColor

        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.alignment = .right

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.alignment = .right

        addSubview(leftLabel)
        addSubview(percentLabel)
        addSubview(timeLabel)

        NSLayoutConstraint.activate([
            leftLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            leftLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            percentLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -12),
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 42)
        ])
    }

    func update(label: String, percent: String, time: String) {
        leftLabel.stringValue = label
        percentLabel.stringValue = percent
        timeLabel.stringValue = time
    }
}

final class MenuActionRowView: NSView {
    private let button: NSButton

    init(title: String, target: AnyObject?, action: Selector?) {
        self.button = NSButton(title: title, target: target, action: action)
        super.init(frame: NSRect(x: 0, y: 0, width: 260, height: 30))
        setup()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func setup() {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isBordered = false
        button.bezelStyle = .inline
        button.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        button.contentTintColor = .labelColor
        button.alignment = .left
        button.setButtonType(.momentaryChange)

        addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            button.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
    }
}
