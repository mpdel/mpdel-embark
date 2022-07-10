;;; mpdel-embark.el ---  Integrate MPDel with Embark   -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Damien Cassou

;; Author: Damien Cassou <damien@cassou.me>
;; Keywords: multimedia

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; TODO

;;; Code:
(require 'libmpdel)
(require 'mpdel-core)
(require 'embark)


(defvar mpdel-embark--commands
  '(mpdel-core-add-to-current-playlist
    mpdel-core-add-to-stored-playlist
    mpdel-core-dired
    mpdel-core-insert-current-playlist
    mpdel-core-replace-current-playlist
    mpdel-core-replace-stored-playlist)
  "List of commands in `mpdel-core-map' to make available in embark.")


;;;###autoload
(defun mpdel-embark-list (&optional entity)
  "Select a child of ENTITY.
If ENTITY is nil, select from all artists."
  (interactive)
  (let ((entity (or entity 'artists)))
    (libmpdel-completing-read-entity
     #'mpdel-embark--main-action
     (format "Entity: ")
     entity
     :category (mpdel-embark--child-category entity))))

(cl-defgeneric mpdel-embark--main-action (entity)
  "Execute the default action when ENTITY is selected.
Open minibuffer completion on the children of ENTITY by default."
  (mpdel-embark-list entity))

(cl-defmethod mpdel-embark--main-action ((song libmpdel-song))
  "Display information about SONG."
  (mpdel-song-open song))

(cl-defgeneric mpdel-embark--child-category (entity)
  "Return the category, a symbol, for children of ENTITY.
The category tells the minibuffer completion engine what is the
type of the listed candidates, e.g., `libmpdel-song'.")

(cl-defmethod mpdel-embark--child-category ((_entity (eql artists)))
  "Return the category for children of 'artists."
  'libmpdel-artist)

(cl-defmethod mpdel-embark--child-category ((_artist libmpdel-artist))
  "Return the category for children of ARTIST."
  'libmpdel-album)

(cl-defmethod mpdel-embark--child-category ((_album libmpdel-album))
  "Return the category for children of ALBUM."
  'libmpdel-song)

(defun mpdel-embark--get-target-from-string (type target)
  (cons type (if (stringp target)
                 (get-text-property 0 'libmpdel-entity target)
               target)))

(defvar mpdel-embark-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map embark-general-map)
    (map-keymap
     (lambda (key command)
       (when (cl-member command mpdel-embark--commands)
         (define-key map (vector key) command)))
     mpdel-core-map)
    map)
  "Embark keymap for mpdel.")

(cl-defun mpdel-embark-fake-selected-entities (&key target &allow-other-keys)
  (cl-labels ((fake-selected-entities
               ()
               (advice-remove 'mpdel-core-selected-entities #'fake-selected-entities)
               (list target)))
    (advice-add 'mpdel-core-selected-entities :override #'fake-selected-entities)))

(defun mpdel-embark--tablist-entity-at-point ()
  "Target the MPDel entity on the line in a tablist buffer."
  (when (derived-mode-p 'mpdel-tablist-mode)
    (when-let ((entity (get-text-property (point) 'tabulated-list-id)))
      `(
        ,(aref entity 0) ;; type of entity
        ,entity
        ,(line-beginning-position) . ,(line-end-position)))))

(defun mpdel-embark-setup ()
  (dolist (command mpdel-embark--commands)
    (setf (alist-get command embark-pre-action-hooks)
          (list #'mpdel-embark-fake-selected-entities)))

  (dolist (category '(libmpdel-artist libmpdel-album libmpdel-song))
    (setf (alist-get category embark-transformer-alist) #'mpdel-embark--get-target-from-string)
    (setf (alist-get category embark-keymap-alist) 'mpdel-embark-map))

  (add-to-list 'embark-target-finders #'mpdel-embark--tablist-entity-at-point))

(provide 'mpdel-embark)
;;; mpdel-embark.el ends here
