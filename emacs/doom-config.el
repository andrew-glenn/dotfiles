;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Make sure you don't have other goimports hooks enabled.
(after! lsp-mode
  (setq  lsp-go-analyses '((fieldalignment . t)
                           (nilness . t)
                           (shadow . t)
                           (unusedparams . t)
                           (unusedwrite . t)
                           (useany . t)
                           (unusedvariable . t)))
)
;; No splash screen. 
(setq inhibit-startup-message t)

;; Display line numbers in every buffer
(global-display-line-numbers-mode 1)

;; Load a theme.
(load-theme 'modus-vivendi' 1)

;; Recent Open Files
(recentf-mode 1)
(winner-mode 1)


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

  (set-docsets! 'go-mode "Go")
  (set-repl-handler! 'go-mode #'gorepl-run)
  (set-lookup-handlers! 'go-mode
    :documentation #'godoc-at-point)
  
  (if (modulep! +lsp)
      (add-hook 'go-mode-local-vars-hook #'lsp! 'append)
    (add-hook 'go-mode-hook #'go-eldoc-setup))
  
  (when (modulep! +tree-sitter)
    (add-hook 'go-mode-local-vars-hook #'tree-sitter! 'append))
  
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
  
  
(use-package! gorepl-mode
  :commands gorepl-run-load-current-file)


(use-package! company-go
   :when (modulep! :completion company)
   :unless (modulep! +lsp)
   :after go-mode
   :config
   (set-company-backend! 'go-mode 'company-go)
   (setq company-go-show-annotation t))

 ; (use-package! flycheck-golangci-lint
 ;   :when (modulep! :checkers syntax -flymake)
 ;   :hook (go-mode . flycheck-golangci-lint-setup))
(use-package eglot
  :ensure t
  :defer t
  :hook (python-mode . eglot-ensure))

;; Keybindings. 
(global-set-key (kbd "C-c .") (lambda () (interactive) (go-fill-struct))
