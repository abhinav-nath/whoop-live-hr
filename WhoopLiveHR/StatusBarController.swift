import AppKit
import SwiftUI
import Combine

final class StatusBarController:
    NSObject {

    // MARK: Status item

    private let statusItem:
        NSStatusItem


    // MARK: Popover

    private let popover =
        NSPopover()


    // MARK: Dependencies

    private let heartRateManager:
        HeartRateManager


    // MARK: Combine

    private var cancellables =
        Set<AnyCancellable>()


    // MARK: Layout

    /*
     Fixed width.

     This is deliberately NOT
     NSStatusItem.variableLength.

     The menu-bar slot therefore doesn't
     grow/shrink as BPM moves between
     two and three digits.
     */
    private let statusItemWidth:
        CGFloat = 58


    // MARK: Init

    init(
        heartRateManager:
            HeartRateManager
    ) {

        self.heartRateManager =
            heartRateManager

        self.statusItem =
            NSStatusBar.system.statusItem(
                withLength:
                    statusItemWidth
            )

        super.init()

        configureStatusItem()

        configurePopover()

        observeHeartRateManager()
    }


    // MARK: Status item setup

    private func configureStatusItem() {

        guard
            let button =
                statusItem.button
        else {
            return
        }


        let heart =
            NSImage(
                systemSymbolName:
                    "heart.fill",
                accessibilityDescription:
                    "Heart Rate"
            )


        /*
         Template images automatically adapt to
         dark/light menu bars.
         */
        heart?.isTemplate = true


        button.image =
            heart

        button.imagePosition =
            .imageLeft

        button.imageScaling =
            .scaleProportionallyDown


        /*
         Every digit gets identical width.
         */
        button.font =
            NSFont.monospacedDigitSystemFont(
                ofSize:
                    NSFont.systemFontSize,
                weight:
                    .regular
            )


        button.alignment =
            .center


        button.target =
            self

        button.action =
            #selector(
                togglePopover
            )


        updateStatusItem()

        updateToolTip()
    }


    // MARK: Status item updates

    private func updateStatusItem() {

        guard
            let button =
                statusItem.button
        else {
            return
        }


        if let bpm =
            heartRateManager.heartRate {

            /*
             Always exactly three character slots:

              72 -> " 72"
              96 -> " 96"
              99 -> " 99"
             100 -> "100"
             101 -> "101"
             */
            button.title =
                String(
                    format:
                        "%3d",
                    bpm
                )

        } else {

            button.title =
                " --"
        }
    }


    private func updateToolTip() {

        guard
            let button =
                statusItem.button
        else {
            return
        }


        if let bpm =
            heartRateManager.heartRate {

            button.toolTip =
                "\(bpm) BPM • \(heartRateManager.status)"

        } else {

            button.toolTip =
                heartRateManager.status
        }
    }


    // MARK: Popover

    private func configurePopover() {

        popover.behavior =
            .transient

        popover.animates =
            true

        popover.contentSize =
            NSSize(
                width: 340,
                height: 340
            )


        popover.contentViewController =
            NSHostingController(
                rootView:
                    StatusPopoverView(
                        heartRateManager:
                            heartRateManager
                    )
            )
    }


    @objc
    private func togglePopover() {

        guard
            let button =
                statusItem.button
        else {
            return
        }


        if popover.isShown {

            popover.performClose(nil)

            return
        }


        popover.show(
            relativeTo:
                button.bounds,
            of:
                button,
            preferredEdge:
                .minY
        )
    }


    // MARK: Observation

    private func observeHeartRateManager() {

        /*
         Heart-rate changes update the status
         item immediately.

         No polling Timer required.
         */
        heartRateManager
            .$heartRate
            .removeDuplicates()
            .receive(
                on: RunLoop.main
            )
            .sink {
                [weak self] _ in

                self?.updateStatusItem()

                self?.updateToolTip()
            }
            .store(
                in: &cancellables
            )


        heartRateManager
            .$status
            .removeDuplicates()
            .receive(
                on: RunLoop.main
            )
            .sink {
                [weak self] _ in

                self?.updateToolTip()
            }
            .store(
                in: &cancellables
            )
    }
}
