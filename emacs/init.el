;; No splash screen. 
(setq inhibit-startup-message t)

;; Display line numbers in every buffer
(global-display-line-numbers-mode 1)

;; Load a theme.
(load-theme 'modus-vivendi' 1)

;; Recent Open Files
(recentf-mode 1)
(winner-mode 1)

;; Move customization variables to a separate file and load it
(setq custom-file (locate-user-emacs-file "custom-vars.el"))
(load custom-file 'noerror 'nomessage)

;; Revert buffers if the underlying file on disk has changed. 
(global-auto-revert-mode 1)
(xterm-mouse-mode)
;; Electric pair mode
(electric-pair-mode 1) 
;; Configure the Modus Themes' appearance
(setq modus-themes-mode-line '(accented borderless)
      modus-themes-bold-constructs t
      modus-themes-italic-constructs t
      modus-themes-fringes 'subtle
      modus-themes-tabs-accented t
      modus-themes-paren-match '(bold intense)
      modus-themes-prompts '(bold intense)
      modus-themes-completions 'opinionated
      modus-themes-org-blocks 'tinted-background
      modus-themes-scale-headings t
      modus-themes-region '(bg-only)
      modus-themes-headings
      '((1 . (rainbow overline background 1.4))
        (2 . (rainbow background 1.3))
        (3 . (rainbow bold 1.2))
        (t . (semilight 1.1))))

;; Enable Evil
(require 'evil)
(evil-mode 1)

;; Packages. 
;; Set up package.el to work with MELPA
(require 'package)
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/"))
(package-initialize)

;; Download Evil
(unless (package-installed-p 'evil)
  (package-install 'evil))

;; Download Go-mode
(unless (package-installed-p 'go-mode)
  (package-install 'go-mode))

(require 'go-mode)

;; Set up Go-specific key bindings
(add-hook 'go-mode-hook
          (lambda ()
            (setq tab-width 4)
            (setq indent-tabs-mode 1)))

;; Enable auto-completion
(add-hook 'go-mode-hook 'company-mode)

;; Enable Flycheck for real-time syntax checking
(add-hook 'go-mode-hook 'flycheck-mode)

;; Enable automatic formatting on save
(add-hook 'before-save-hook 'gofmt-before-save)



(use-package eglot
  :ensure t
  :defer t
  :hook (python-mode . eglot-ensure))


(use-package lsp-mode
  :ensure t
  :commands (lsp lsp-mode lsp-deferred)
  :hook ((rust-mode python-mode go-mode) . lsp-deferred)
  :config
  (setq lsp-prefer-flymake nil
        lsp-enable-indentation nil
        lsp-enable-on-type-formatting nil
        lsp-rust-server 'rust-analyzer)
  ;; for filling args placeholders upon function completion candidate selection
  ;; lsp-enable-snippet and company-lsp-enable-snippet should be nil with
  ;; yas-minor-mode is enabled: https://emacs.stackexchange.com/q/53104
  (lsp-modeline-code-actions-mode)
  (add-hook 'lsp-mode-hook #'lsp-enable-which-key-integration)
  (add-to-list 'lsp-file-watch-ignored "\\.vscode\\'"))	


(require 'project)
	; OSX command key as control
(setq mac-command-modifier 'control)
(global-set-key (kbd "<select>") 'move-end-of-line) 

; go-fill-struct immediately followed by gofmt
(global-set-key (kbd "C-c .") (lambda () (interactive) (go-fill-struct) (gofmt)))

(defun my/fake-menu-find-file-existing ()
  (interactive)
  (let ((use-dialog-box t)
         (use-file-dialog t)
         (last-nonmenu-event nil))
    (menu-find-file-existing)))

(define-key global-map (kbd "C-c C-o") 'my/fake-menu-find-file-existing)
;;; lang/go/config.el -*- lexical-binding: t; -*-

;;
;;; Packages

  ; (set-docsets! 'go-mode "Go")
  ; (set-repl-handler! 'go-mode #'gorepl-run)
  ; (set-lookup-handlers! 'go-mode
  ;   :documentation #'godoc-at-point)
  ;
  ; (if (modulep! +lsp)
  ;     (add-hook 'go-mode-local-vars-hook #'lsp! 'append)
  ;   (add-hook 'go-mode-hook #'go-eldoc-setup))
  ;
  ; (when (modulep! +tree-sitter)
  ;   (add-hook 'go-mode-local-vars-hook #'tree-sitter! 'append))
  ;
  ; (map! :map go-mode-map
  ;       :localleader
  ;       "a" #'go-tag-add
  ;       "d" #'go-tag-remove
  ;       "e" #'+go/play-buffer-or-region
  ;       "i" #'go-goto-imports      ; Go to imports
  ;       (:prefix ("h" . "help")
  ;         "." #'godoc-at-point)    ; Lookup in godoc
  ;       (:prefix ("ri" . "imports")
  ;         "a" #'go-import-add)
  ;       (:prefix ("b" . "build")
  ;         :desc "go run ." "r" (cmd! (compile "go run ."))
  ;         :desc "go build" "b" (cmd! (compile "go build"))
  ;         :desc "go clean" "c" (cmd! (compile "go clean")))
  ;       (:prefix ("t" . "test")
  ;         "t" #'+go/test-rerun
  ;         "a" #'+go/test-all
  ;         "s" #'+go/test-single
  ;         "n" #'+go/test-nested
  ;         "f" #'+go/test-file
  ;         "g" #'go-gen-test-dwim
  ;         "G" #'go-gen-test-all
  ;         "e" #'go-gen-test-exported
  ;         (:prefix ("b" . "bench")
  ;           "s" #'+go/bench-single
  ;           "a" #'+go/bench-all))))
  ;
  ;
; (use-package! gorepl-mode
;   :commands gorepl-run-load-current-file)
;
;
; (use-package! company-go
;   :when (modulep! :completion company)
;   :unless (modulep! +lsp)
;   :after go-mode
;   :config
;   (set-company-backend! 'go-mode 'company-go)
;   (setq company-go-show-annotation t))
;
;
; (use-package! flycheck-golangci-lint
;   :when (modulep! :checkers syntax -flymake)
;   :hook (go-mode . flycheck-golangci-lint-setup))
;
(use-package eglot
  :ensure t
  :defer t
  :hook (python-mode . eglot-ensure))
