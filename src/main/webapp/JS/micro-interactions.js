/**
 * scSAID Micro-Interactions System
 * Orchestrates animations and transitions across the application
 * Version: 1.0.0
 */

(function() {
    'use strict';

    /* ========================================================================
       Animation Orchestrator
       ======================================================================== */

    const MicroInteractions = {

        // Configuration
        config: {
            staggerDelay: 80,
            pageTransitionDuration: 600,
            feedbackDuration: 3000,
            reducedMotion: window.matchMedia('(prefers-reduced-motion: reduce)').matches
        },

        /* ====================================================================
           1. Page Transitions - Blur & Scale
           ==================================================================== */

        initPageTransitions: function() {
            if (this.config.reducedMotion) return;

            // Add page transition class on load
            document.body.classList.add('page-transition');

            // Intercept link clicks for smooth transitions
            document.addEventListener('click', (e) => {
                const link = e.target.closest('a');
                if (!link || link.target === '_blank' || link.hostname !== window.location.hostname) return;

                // Skip if has specific data attribute to skip transition
                if (link.hasAttribute('data-no-transition')) return;

                // Check if it's a hash link (anchor on same page)
                if (link.hash && link.pathname === window.location.pathname) return;

                e.preventDefault();
                const href = link.href;

                // Exit animation
                document.body.classList.add('page-transition-exit');

                setTimeout(() => {
                    window.location.href = href;
                }, this.config.pageTransitionDuration);
            });
        },

        /* ====================================================================
           2. Staggered Entrance - Lists, Cards, Panels
           ==================================================================== */

        initStaggeredEntrance: function() {
            if (this.config.reducedMotion) return;

            // Auto-detect and animate stagger items on page load
            const staggerGroups = document.querySelectorAll('[data-stagger-group]');

            staggerGroups.forEach(group => {
                const items = group.querySelectorAll('[data-stagger-item]');
                const animationType = group.getAttribute('data-stagger-type') || 'fade-up';

                items.forEach((item, index) => {
                    // Apply base animation class
                    switch(animationType) {
                        case 'slide-left':
                            item.classList.add('stagger-slide-left');
                            break;
                        case 'scale':
                            item.classList.add('stagger-scale');
                            break;
                        case 'fade-up':
                        default:
                            item.classList.add('stagger-item');
                            break;
                    }

                    // Apply delay
                    const delay = index * this.config.staggerDelay;
                    item.style.animationDelay = `${delay}ms`;
                });
            });

            // Special handling for panels (details page)
            const panels = document.querySelectorAll('[data-panel-enter]');
            panels.forEach((panel, index) => {
                panel.classList.add('panel-enter');
                panel.style.animationDelay = `${index * 120}ms`;
            });
        },

        /* ====================================================================
           3. Button Morphing - Submit/Action Buttons
           ==================================================================== */

        initButtonMorphing: function() {
            const morphButtons = document.querySelectorAll('[data-btn-morph]');

            morphButtons.forEach(button => {
                button.classList.add('btn-morph');

                button.addEventListener('click', (e) => {
                    if (button.classList.contains('is-processing')) {
                        e.preventDefault();
                        return;
                    }

                    // Press animation
                    button.classList.add('is-pressing');
                    setTimeout(() => button.classList.remove('is-pressing'), 150);

                    // Ripple effect
                    button.classList.add('is-rippling');
                    setTimeout(() => button.classList.remove('is-rippling'), 600);
                });
            });
        },

        /* ====================================================================
           4. Outcome Feedback Animations
           ==================================================================== */

        showFeedback: function(type, message, target) {
            if (!target) target = document.body;

            // Create toast element
            const toast = document.createElement('div');
            toast.className = `feedback-toast feedback-toast--${type}`;
            toast.setAttribute('role', 'alert');
            toast.innerHTML = `
                <div class="feedback-toast__icon">
                    ${type === 'success' ? this._getSuccessIcon() : this._getErrorIcon()}
                </div>
                <div class="feedback-toast__message">${message}</div>
            `;

            // Add to container
            let container = document.querySelector('.feedback-container');
            if (!container) {
                container = document.createElement('div');
                container.className = 'feedback-container';
                document.body.appendChild(container);
            }
            container.appendChild(toast);

            // Auto-remove after duration
            setTimeout(() => {
                toast.classList.add('is-exiting');
                setTimeout(() => toast.remove(), this.config.pageTransitionDuration);
            }, this.config.feedbackDuration);
        },

        _getSuccessIcon: function() {
            return `<svg class="feedback-check" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                <polyline points="20 6 9 17 4 12" stroke-dasharray="100" stroke-dashoffset="100"></polyline>
            </svg>`;
        },

        _getErrorIcon: function() {
            return `<svg class="feedback-error" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
                <circle cx="12" cy="12" r="10"></circle>
                <line x1="15" y1="9" x2="9" y2="15"></line>
                <line x1="9" y1="9" x2="15" y2="15"></line>
            </svg>`;
        },

        // Button state helpers
        setButtonState: function(button, state) {
            button.classList.remove('is-pressing', 'is-processing', 'is-success', 'is-error');

            switch(state) {
                case 'processing':
                    button.classList.add('is-processing');
                    button.disabled = true;
                    break;
                case 'success':
                    button.classList.add('is-success');
                    button.disabled = false;
                    setTimeout(() => button.classList.remove('is-success'), 1200);
                    break;
                case 'error':
                    button.classList.add('is-error');
                    button.disabled = false;
                    setTimeout(() => button.classList.remove('is-error'), 600);
                    break;
                default:
                    button.disabled = false;
            }
        },

        /* ====================================================================
           6. Data Table Animations
           ==================================================================== */

        animateTableRows: function(table) {
            if (this.config.reducedMotion) return;

            const rows = table.querySelectorAll('tbody tr');
            rows.forEach((row, index) => {
                row.classList.add('table-row-enter');
                row.style.animationDelay = `${index * 30}ms`;
            });
        },

        /* ====================================================================
           7. Chart/Plot Entrance
           ==================================================================== */

        animateChart: function(chartElement) {
            if (this.config.reducedMotion) return;
            chartElement.classList.add('chart-enter');
        },

        /* ====================================================================
           8. Utility Methods
           ==================================================================== */

        // Programmatically trigger stagger animation on new elements
        staggerNewItems: function(items, animationType = 'fade-up') {
            items.forEach((item, index) => {
                setTimeout(() => {
                    switch(animationType) {
                        case 'slide-left':
                            item.classList.add('stagger-slide-left');
                            break;
                        case 'scale':
                            item.classList.add('stagger-scale');
                            break;
                        default:
                            item.classList.add('stagger-item');
                    }
                }, index * this.config.staggerDelay);
            });
        },

        // Badge pop animation
        popBadge: function(badge) {
            badge.classList.add('badge-pop');
        },

        // Number animation placeholder (use CountUp.js for real implementation)
        animateNumber: function(element) {
            element.classList.add('number-countup');
        },

        /* ====================================================================
           Initialization
           ==================================================================== */

        init: function() {
            // Wait for DOM to be ready
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => this._initAll());
            } else {
                this._initAll();
            }
        },

        _initAll: function() {
            this.initPageTransitions();
            this.initStaggeredEntrance();
            this.initButtonMorphing();

            // Add styles for feedback container
            this._injectStyles();

            // Mark as initialized
            document.documentElement.classList.add('micro-interactions-ready');
        },

        _injectStyles: function() {
            const style = document.createElement('style');
            style.textContent = `
                .feedback-container {
                    position: fixed;
                    top: 90px;
                    right: 2rem;
                    z-index: 10000;
                    display: flex;
                    flex-direction: column;
                    gap: 1rem;
                    pointer-events: none;
                }

                .feedback-toast {
                    display: flex;
                    align-items: center;
                    gap: 1rem;
                    padding: 1rem 1.5rem;
                    background: #ffffff;
                    border-radius: 12px;
                    box-shadow: 0 8px 32px rgba(26, 35, 50, 0.15);
                    pointer-events: all;
                    min-width: 320px;
                    border-left: 4px solid;
                }

                .feedback-toast--success {
                    border-left-color: #4caf50;
                }

                .feedback-toast--error {
                    border-left-color: #dc3c3c;
                }

                .feedback-toast__icon {
                    flex-shrink: 0;
                    width: 24px;
                    height: 24px;
                }

                .feedback-toast--success .feedback-toast__icon {
                    color: #4caf50;
                }

                .feedback-toast--error .feedback-toast__icon {
                    color: #dc3c3c;
                }

                .feedback-toast__message {
                    font-family: 'Montserrat', sans-serif;
                    font-size: 0.9rem;
                    color: #1a2332;
                    line-height: 1.5;
                }

                @media (max-width: 768px) {
                    .feedback-container {
                        right: 1rem;
                        left: 1rem;
                    }
                    .feedback-toast {
                        min-width: auto;
                    }
                }
            `;
            document.head.appendChild(style);
        }
    };

    /* ========================================================================
       Global API - Expose to window
       ======================================================================== */

    window.MicroInteractions = MicroInteractions;

    // Auto-initialize
    MicroInteractions.init();

})();
