(load "~/Documents/aoc/util.lisp")

(defun read-all-lines (filename)
  (with-open-file (strm filename)
    (do* ((r t (read-line strm nil))
	  (acc nil (cons r acc)))
	 ((null r) (nreverse (cdr acc))))))
;; - t in (r t ...) not consed: do* -> cons only after read-line
;; - cdr acc because last r is nil and is consed

(defun list-to-vector (lst)
  (coerce lst 'vector))

(defun position-table (grid)
  (let ((tab (make-hash-table)))
    (dotimes (r (length grid))
      (dotimes (c (length (elt grid 0)))
	(let ((ch (elt (elt grid r) c)))
	  (when (or (lower-case-p ch) (eql ch #\@))
	    (setf (gethash ch tab) (list r c))))))
    tab))

(defun canon (c1 c2)
  (if (char<= c1 c2) (list c1 c2) (list c2 c1)))

(defun bfs (grid r0 c0 pair-table)
  (let ((q (make-singleton-queue (list (list r0 c0) nil 0)))
	(seen (make-hash-table :test 'equal))
	(ch0 (elt (elt grid r0) c0)))
    (setf (gethash (list r0 c0) seen) t)
    (do () ((queue-empty q))
      (let* ((q-elem (dequeue q))
	     (rq (caar q-elem))
	     (cq (cadar q-elem))
	     (n-dist (1+ (caddr q-elem)))
	     (doorsq (cadr q-elem)))
	(dolist (step '((1 0) (-1 0) (0 1) (0 -1)))
	  (let* ((r (+ rq (car step)))
		 (c (+ cq (cadr step)))
		 (ch (elt (elt grid r) c)))
	    (when (not (or (eql #\# ch)
			   (gethash (list r c) seen)))
	      (setf (gethash (list r c) seen) t)
	      (cond ((or (eql #\. ch) (eql #\@ ch))
		     (enqueue q (list (list r c) doorsq n-dist)))
		    ((upper-case-p ch)
		     (enqueue q (list (list r c) (cons ch doorsq) n-dist)))
		    ((lower-case-p ch)
		     (enqueue q (list (list r c) doorsq n-dist))  ;; note 1
		     (setf (gethash (canon ch ch0) pair-table)
			   (list n-dist
				 (map 'string 'identity doorsq))))))))))))
;; note 1: at first I thought no need to enqueue. But we need to handle cases
;; where a path doubles back through an already visited lowercase.

(defun get-lowers (grid)
  (let ((out nil))
    (dotimes (r (length grid))
      (dotimes (c (length (elt grid 0)))
	(let ((ch (elt (elt grid r) c)))
	  (when (lower-case-p ch)
	    (push ch out)))))
    out))

(defun compute-pair-table (grid)
  (let* ((pair-table (make-hash-table :test 'equal))
	 (pos-table (position-table grid))
	 (pos-amp (gethash #\@ pos-table)))
    (bfs grid (car pos-amp) (cadr pos-amp) pair-table)
    (dolist (lett (get-lowers grid))
      (let ((pos-lett (gethash lett pos-table)))
	(bfs grid (car pos-lett) (cadr pos-lett) pair-table)))
    pair-table))

(defun debug-table (tab)
  (maphash (lambda (k v)
	     (format t "~A : ~A~%" k v))
	   tab))

(defstruct min-heap
  (before #'<=)
  (arr (make-array 1 :adjustable t :fill-pointer 0)))

(defstruct mh-elem key val)

(defun parent (i) (floor (1- i) 2))
(defun left-child (i) (1+ (* 2 i)))
(defun right-child (i) (+ 2 (* 2 i)))
(defun heap-length (hp) (length (min-heap-arr hp)))

(defun indmin (arr i k)
  (let ((key-i (mh-elem-key (elt arr i)))
	(key-k (mh-elem-key (elt arr k))))
    (if (<= key-i key-k) i k)))

(defun min-heapify (hp i)
  (let* ((arr (min-heap-arr hp))
	 (l (left-child i))
	 (r (right-child i))
	 (len (heap-length hp))
	 (m i))
    (when (< l len) (setf m (indmin arr m l)))
    (when (< r len) (setf m (indmin arr m r)))
    (when (/= m i)
      (rotatef (elt arr m) (elt arr i))
      (min-heapify hp m))))

(defun min-pop (hp)
  (let ((arr (min-heap-arr hp)))
    (rotatef (elt arr 0)
	     (elt arr (1- (heap-length hp))))
    (let ((min-elem (vector-pop arr)))
      (min-heapify hp 0)
      min-elem)))

(defun decrease-key (hp i to-val)
  (let ((arr (min-heap-arr hp)))
    (do () ((or (= i 0)
		(<= (mh-elem-key (elt arr (parent i)))
		    to-val)))
      (rotatef (elt arr i) (elt arr (parent i)))
      (setf i (parent i)))
    (when (< to-val (mh-elem-key (elt arr i)))
      (setf (mh-elem-key (elt arr i)) to-val))))
;; we know it's decrease not increase because adding inf at end is initially
;; correct; it's only when we make it smaller does it need to propagate up

(defparameter *huge* 100000000000)

(defun min-insert (hp elem)
  (let ((arr (min-heap-arr hp))
	(key (mh-elem-key elem)))
    (setf (mh-elem-key elem) *huge*)
    (vector-push-extend elem arr)
    (decrease-key hp (1- (heap-length hp)) key)))

(defun get-lowercase-in (pair-table)
  (let ((out-map (make-hash-table))
	(out-lst nil))
    (maphash (lambda (k v)
	       (declare (ignore v))
	       (dolist (ch k)
		 (when (lower-case-p ch)
		   (setf (gethash ch out-map) t))))
	     pair-table)
    (maphash (lambda (k v)
	       (declare (ignore v))
	       (push k out-lst))
	     out-map)
    out-lst))

(defun every-door-can-open (path doors)
  (every (lambda (d) (find (char-downcase d) path))
	 doors))

(defun can-append-dist (next-ch prev-ch path-before pair-table)
  (and (not (find next-ch path-before))
       (not (char= next-ch prev-ch))
       (let ((entry (gethash (canon next-ch prev-ch) pair-table))
	     (path (concatenate 'string path-before (string prev-ch))))
	 (and (every-door-can-open path (cadr entry))
	      (car entry)))))

(defun combine-sorted (ch str)
  (sort (concatenate 'string str (string ch))
	'char<=))

(defun solve-part-1 (pair-table)
  (let ((hp (make-min-heap))
	(lowers (get-lowercase-in pair-table))
	;; equalp not equal because will have strings
	;; heap optimization for Djikstra
	(record-table (make-hash-table :test 'equalp)))
    (dolist (ch lowers)
      (let ((r (gethash (list #\@ ch) pair-table))
	    (path-record0 (list ch "")))
	(when (and r (string= "" (cadr r)))
	  (setf (gethash path-record0 record-table) (car r))
	  (min-insert hp (make-mh-elem :key (car r)
				       :val path-record0)))))
    (do () ((zerop (heap-length hp))
	    (error "unexpected empty heap"))
      (let* ((hm (min-pop hp))
	     (dist (mh-elem-key hm))
	     (path-record (mh-elem-val hm)))
	(when (= (length lowers) (1+ (length (cadr path-record))))
	  (return-from solve-part-1 dist))
	;; need to skip if not as good as record, the better one may have
	;; already been dequeued
	(when (= dist (gethash path-record record-table))
	  (dolist (next-ch lowers)
	    (let* ((prev-ch (car path-record))
		   (path-before (cadr path-record))
		   (next-path-str (combine-sorted prev-ch path-before))
		   (dist-or (can-append-dist next-ch prev-ch path-before pair-table))
		   ;; aka next-path-record
		   (record-key (list next-ch next-path-str))
		   (record-entry (gethash record-key record-table)))
	      (when dist-or
		(let ((next-dist (+ dist-or dist)))
		  (when (or (null record-entry)
			    (< next-dist record-entry))
		    (setf (gethash record-key record-table) next-dist)
		    (min-insert
		     hp
		     (make-mh-elem
		      :key next-dist
		      :val (list next-ch next-path-str)))))))))))))

(let* ((grid (list-to-vector (read-all-lines "~/Documents/aoc/input18.txt")))
       (pair-table (compute-pair-table grid)))
  (format t "part 1 = ~A~%" (solve-part-1 pair-table)))
;; 5288
