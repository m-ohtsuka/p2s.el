;; p2s.el --- Post to multiple SNS services simultaneously -*- lexical-binding: t -*-

;; ## 使い方
;;
;; 1. このコードを `p2s.el` として保存し、ロードパスに配置
;; 2. 設定ファイルに以下を追加:
;;
;; ```elisp
;; (require 'p2s)
;; ;; 任意: 推奨キーバインドをセットアップ
;; (p2s-setup-keybindings)
;; ```
;;
;; 3. または use-package を使用:
;;
;; ```elisp
;; (use-package p2s
;;   :load-path "~/path/to/p2s"
;;   :bind (("C-c p r" . p2s-post-region-to-all-services)
;;          ("C-c p m" . p2s-post-from-minibuffer-to-all)
;;          ("C-c p c" . p2s-configure-services))
;;   :config
;;   (setq p2s-max-length 500))  ;; 必要に応じて文字数制限を変更
;; ```
;;
;; ## 主な機能
;;
;; - **`p2s-post-region-to-all-services`**: 選択範囲を全サービスに投稿（300文字超で警告）
;; - **`p2s-post-from-minibuffer-to-all`**: ミニバッファから投稿（300文字超で警告）
;; - **`p2s-configure-services`**: 投稿するサービスを選択
;; - **`p2s-setup-keybindings`**: 推奨キーバインドの設定
;;
;; なお、300文字を超える投稿は `user-error` でブロックされ、投稿処理は実行されません。

;; Author: @ohtsuka
;; Version: 0.1
;; Keywords: convenience
;; Package-Requires: ((emacs "25.1"))

;;; Commentary:
;; This package provides functions to post content to multiple social network
;; services simultaneously, such as Bluesky and Mastodon.

;;; Code:

(defgroup p2s nil
  "Post to multiple SNS services simultaneously."
  :group 'communication)

(defcustom p2s-services '(bsky toot)
  "投稿対象のソーシャルメディアサービスのリスト。"
  :type '(repeat symbol)
  :group 'p2s)

(defcustom p2s-service-commands
  '((bsky . ("bsky" "post" "--stdin"))
    (toot . ("toot" "post")))
  "各サービスの投稿コマンド。"
  :type '(alist :key-type symbol :value-type (repeat string))
  :group 'p2s)

(defcustom p2s-max-length 300
  "投稿の最大文字数。"
  :type 'integer
  :group 'p2s)

(defun p2s-check-length (text)
  "TEXTの長さを確認し、最大文字数を超えている場合はエラーを出力する。"
  (let ((len (length text)))
    (when (> len p2s-max-length)
      (user-error "投稿が長すぎます（%d文字）。%d文字以内にしてください"
                 len p2s-max-length))
    t))

(defun p2s-post-region-to-all-services (begin end)
  "現在のリージョンの内容を設定されたすべてのサービスに同時投稿する。
BEGIN ENDはリージョンの開始位置と終了位置。"
  (interactive "r")
  (let ((text (buffer-substring-no-properties begin end)))
    (if (zerop (length (string-trim text)))
        (message "Empty region, nothing to post")
      (when (p2s-check-length text)
        (p2s-post-text-to-all-services text)))))

(defun p2s-post-text-to-all-services (text)
  "テキストをすべてのサービスに投稿する。"
  (let ((success-count 0)
        (service-count (length p2s-services)))

    (dolist (service p2s-services)
      (let* ((command (cdr (assq service p2s-service-commands)))
             (process-connection-type nil)
             (proc-name (format "p2s-%s-process" service))
             (buffer-name (format "*p2s-%s-output*" service)))

        (if (not command)
            (message "Unknown service: %s" service)
          ;; プロセス開始
          (let ((proc (apply #'start-process proc-name buffer-name command)))
            (process-send-string proc text)
            (process-send-eof proc)
            ;; プロセス終了時のコールバック設定
            (set-process-sentinel
             proc
             (lambda (process event)
               (when (string-match "finished" event)
                 (setq success-count (1+ success-count))
                 (message "Posted to %s (%d/%d complete)"
                          service success-count service-count)
                 (when (= success-count service-count)
                   (message "Successfully posted to all %d services" service-count))))))))))

  (message "Sending post to all services..."))

(defun p2s-post-from-minibuffer-to-all ()
  "ミニバッファからテキストを入力して、すべてのサービスに同時投稿する。"
  (interactive)
  (let ((text (read-string "Post to all services: ")))
    (if (zerop (length (string-trim text)))
        (message "Empty text, nothing to post")
      (when (p2s-check-length text)
        (p2s-post-text-to-all-services text)))))

(defun p2s-configure-services ()
  "投稿したいソーシャルメディアサービスを設定する。"
  (interactive)
  (let* ((available-services (mapcar #'car p2s-service-commands))
         (chosen-services
          (mapcar #'intern
                  (completing-read-multiple
                   "Select services to post to (comma separated): "
                   (mapcar #'symbol-name available-services)
                   nil t
                   (mapconcat #'symbol-name p2s-services ",")))))
    (setq p2s-services chosen-services)
    (message "Social services set to: %s" p2s-services)))

;;;###autoload
(defun p2s-post-buffer-to-all-services ()
  "現在のバッファの内容をすべてのサービスに投稿する。"
  (interactive)
  (p2s-post-region-to-all-services (point-min) (point-max)))

;;;###autoload
(defun p2s-setup-keybindings ()
  "p2sの推奨キーバインドを設定する。"
  (interactive)
  (global-set-key (kbd "C-c p r") 'p2s-post-region-to-all-services)
  (global-set-key (kbd "C-c p m") 'p2s-post-from-minibuffer-to-all)
  (global-set-key (kbd "C-c p c") 'p2s-configure-services)
  (message "p2s keybindings set up"))

(provide 'p2s)
;;; p2s.el ends here
