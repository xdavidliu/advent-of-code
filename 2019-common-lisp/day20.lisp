(load "~/Documents/aoc/util.lisp")

(defun portal-table (grid)
  (let ((table (make-hash-table :test 'equal)))
    (dotimes (r (length grid))
      (dotimes (c (length (elt grid 0)))
	(when (upper-case-p (elt (elt grid r) c))
	  (maybe-insert-portal grid table r c))))
    table))

(defun make-label (c1 c2)
  (coerce (list c1 c2) 'string))

(defun find-vertical-dot (grid r c)
  (if (and (> r 0)
	   (eql #\. (elt (elt grid (1- r)) c)))
      (list (1- r) c)
      (list (+ 2 r) c)))

(defun find-horizontal-dot (grid r c)
  (if (and (> c 0)
	   (eql #\. (elt (elt grid r) (1- c))))
      (list r (1- c))
      (list r (+ 2 c))))

(defun below-if-upper (grid r c)
  (and (< r (1- (length grid)))
       (let ((ch (elt (elt grid (1+ r)) c)))
	 (and (upper-case-p ch) ch))))

(defun right-if-upper (grid r c)
  (and (< c (1- (length (elt grid 0))))
       (let ((ch (elt (elt grid r) (1+ c))))
	 (and (upper-case-p ch) ch))))

(defun maybe-insert-portal (grid table r c)
  (let (other-ch find-func)
    (cond ((setf other-ch (below-if-upper grid r c))
	   (setf find-func #'find-vertical-dot))
	  ((setf other-ch (right-if-upper grid r c))
	   (setf find-func #'find-horizontal-dot)))
    (when other-ch
      (push (funcall find-func grid r c)
	    (gethash (make-label (elt (elt grid r) c) other-ch)
		     table)))))

(defun make-point-to-point (l2p)
  (let ((p2p (make-hash-table :test 'equal)))
    (maphash (lambda (k v)
	       (declare (ignore k))
	       (when (cdr v)
		 (setf (gethash (car v) p2p) (cadr v)
		       (gethash (cadr v) p2p) (car v))))
	     l2p)
    p2p))

(defun compute-level (prev-lev pos2 bounds)
  (cond ((null bounds) 0)
	((null pos2) prev-lev)  ;; not in p2p
	(t (let ((rmin (car bounds))
		 (rmax (cadr bounds))
		 (cmin (caddr bounds))
		 (cmax (cadddr bounds)))
	     (if (or (= rmin (car pos2))
		     (= rmax (car pos2))
		     (= cmin (cadr pos2))
		     (= cmax (cadr pos2)))
		 (1+ prev-lev)
		 (1- prev-lev))))))

(defun bfs (grid l2p p2p bounds)
  (let* ((start (car (gethash "AA" l2p)))
	 (end (car (gethash "ZZ" l2p)))
	 (seen (make-hash-table :test 'equal))
	 (q (make-singleton-queue (list 0 0 start))))
    (setf (gethash (list 0 start) seen) t)
    (do () ((queue-empty q) (error "unexpectedly empty"))
      (let* ((elem (dequeue q))
	     (levq (car elem))
	     (dq (cadr elem))
	     (rq (caaddr elem))
	     (cq (cadadr (cdr elem))))
	(dolist (dpos '((1 0) (-1 0) (0 1) (0 -1)))
	  (let* ((rd (+ rq (car dpos)))
		 (cd (+ cq (cadr dpos)))
		 (keyd (list levq (list rd cd))))
	    (when (and (eql #\. (elt (elt grid rd) cd))
		       (null (gethash keyd seen)))
	      (when (equal (list 0 end) keyd)
		(return-from bfs (1+ dq)))
	      (setf (gethash keyd seen) t)
	      (let* ((pos2 (gethash (cadr keyd) p2p))
		     (lev2 (compute-level levq pos2 bounds)))
		(cond ((< lev2 0) nil)  ;; stops outer portals at level 0
		      (pos2
		       (enqueue q (list lev2 (+ 2 dq) pos2))
		       (setf (gethash (list lev2 pos2) seen) t))
		      (t (enqueue q (list lev2
					  (1+ dq)
					  (list rd cd)))))))))))))

(defun compute-bounds (p2p)
  (let ((rmin *huge*)
	(rmax (- *huge*))
	(cmin *huge*)
	(cmax (- *huge*)))
    (maphash (lambda (k v)
	       (declare (ignore k))
	       (let ((r (car k))
		     (c (cadr k)))
		 (when (< r rmin) (setf rmin r))
		 (when (> r rmax) (setf rmax r))
		 (when (< c cmin) (setf cmin c))
		 (when (> c cmax) (setf cmax c))))
	     p2p)
    (list rmin rmax cmin cmax)))

(defun solve ()
  (let* ((grid (coerce (read-some-lines "~/Documents/aoc/input20.txt")
		       'vector))
	 (l2p (portal-table grid))
	 (p2p (make-point-to-point l2p)))
    (format t "part 1 = ~A~%" (bfs grid l2p p2p nil))
    (format t "part 2 = ~A~%" (bfs grid l2p p2p (compute-bounds p2p)))))

(solve)
;; 422
;; 5040