;(define parser-error input-parser-error)

(define (make-xml-token kind head) (cons kind head))

(define xml-token? pair?)

(define xml-token-kind car)

(define xml-token-head cdr)

;(define (cons* first . rest) (let recur ((x first) (rest rest)) (if (pair? rest) (cons x (recur (car rest) (cdr rest))) x)))

(define (equal_? e1 e2) (if (eq? 'A (string->symbol "A")) (equal? e1 e2) (cond ((symbol? e1) (and (symbol? e2) (string-ci=? (symbol->string e1) (symbol->string e2)))) ((pair? e1) (and (pair? e2) (equal_? (car e1) (car e2)) (equal_? (cdr e1) (cdr e2)))) ((vector? e1) (and (vector? e2) (equal_? (vector->list e1) (vector->list e2)))) (else (equal? e1 e2)))))

(define (string-whitespace? str) (let ((len (string-length str))) (cond ((zero? len) #t) ((= 1 len) (char-whitespace? (string-ref str 0))) ((= 2 len) (and (char-whitespace? (string-ref str 0)) (char-whitespace? (string-ref str 1)))) (else (let loop ((i 0)) (or (>= i len) (and (char-whitespace? (string-ref str i)) (loop (+ 1 i)))))))))

(define (assq-values val alist) (let loop ((alist alist) (scanned '())) (cond ((null? alist) (values #f scanned)) ((equal? val (caar alist)) (values (car alist) (append scanned (cdr alist)))) (else (loop (cdr alist) (cons (car alist) scanned))))))

(define (fold-right kons knil lis1) (let recur ((lis lis1)) (if (null? lis) knil (let ((head (car lis))) (kons head (recur (cdr lis)))))))

(define (fold kons knil lis1) (let lp ((lis lis1) (ans knil)) (if (null? lis) ans (lp (cdr lis) (kons (car lis) ans)))))

(define SSAX:S-chars (map ascii->char '(32 9 13 10)))

(define (SSAX:skip-S port) (skip-while SSAX:S-chars port))

(define (SSAX:ncname-starting-char? a-char) (and (char? a-char) (or (char-alphabetic? a-char) (char=? #\_ a-char))))

(define (SSAX:read-NCName port) (let ((first-char (peek-char port))) (or (SSAX:ncname-starting-char? first-char) (parser-error port "XMLNS [4] for '" first-char "'"))) (string->symbol (next-token-of (lambda (c) (cond ((eof-object? c) #f) ((char-alphabetic? c) c) ((string-index "0123456789.-_" c) c) (else #f))) port)))

(define (SSAX:read-QName port) (let ((prefix-or-localpart (SSAX:read-NCName port))) (case (peek-char port) ((#\:) (read-char port) (cons prefix-or-localpart (SSAX:read-NCName port))) (else prefix-or-localpart))))

(define SSAX:Prefix-XML (string->symbol "xml"))

(define name-compare (letrec ((symbol-compare (lambda (symb1 symb2) (cond ((eq? symb1 symb2) '=) ((string<? (symbol->string symb1) (symbol->string symb2)) '<) (else '>))))) (lambda (name1 name2) (cond ((symbol? name1) (if (symbol? name2) (symbol-compare name1 name2) '<)) ((symbol? name2) '>) ((eq? name2 SSAX:largest-unres-name) '<) ((eq? name1 SSAX:largest-unres-name) '>) ((eq? (car name1) (car name2)) (symbol-compare (cdr name1) (cdr name2))) (else (symbol-compare (car name1) (car name2)))))))

(define SSAX:largest-unres-name (cons (string->symbol "#UNRES") (string->symbol "#UNRES")))

(define SSAX:read-markup-token (let () 
(define (skip-comment port) (assert-curr-char '(#\-) "XML [15], second dash" port) (if (not (find-string-from-port? "-->" port)) (parser-error port "XML [15], no -->")) (make-xml-token 'COMMENT #f)) 
(define (read-CDATA port) (assert (string=? "CDATA[" (read-chars->string 6 port))) (make-xml-token 'CDSECT #f)) (lambda (port) (assert-curr-char '(#\<) "start of the token" port) (case (peek-char port) ((#\/) (read-char port) (begin0 (make-xml-token 'END (SSAX:read-QName port)) (SSAX:skip-S port) (assert-curr-char '(#\>) "XML [42]" port))) ((#\?) (read-char port) (make-xml-token 'PI (SSAX:read-NCName port))) ((#\!) (case (peek-next-char port) ((#\-) (read-char port) (skip-comment port)) ((#\[) (read-char port) (read-CDATA port)) (else (make-xml-token 'DECL (SSAX:read-NCName port))))) (else (make-xml-token 'START (SSAX:read-QName port)))))))

(define (SSAX:skip-pi port) (if (not (find-string-from-port? "?>" port)) (parser-error port "Failed to find ?> terminating the PI")))

(define (SSAX:read-pi-body-as-string port) (SSAX:skip-S port) (apply string-append (let loop () (let ((pi-fragment (next-token '() '(#\?) "reading PI content" port))) (if (eqv? #\> (peek-next-char port)) (begin (read-char port) (cons pi-fragment '())) (cons* pi-fragment "?" (loop)))))))

(define (SSAX:skip-internal-dtd port) (if (not (find-string-from-port? "]>" port)) (parser-error port "Failed to find ]> terminating the internal DTD subset")))

;(define *return* (ascii->char 13))

(define SSAX:read-CDATA-body (let ((nl-str (string #\newline))) (lambda (port str-handler seed) (let loop ((seed seed)) (let ((fragment (next-token '() (list #\newline #\] #\&) "reading CDATA" port))) (case (read-char port) ((#\newline) (loop (str-handler fragment nl-str seed))) ((#\]) (if (not (eqv? (peek-char port) #\])) (loop (str-handler fragment "]" seed)) (let check-after-second-braket ((seed (if (string-null? fragment) seed (str-handler fragment "" seed)))) (case (peek-next-char port) ((#\>) (read-char port) seed) ((#\]) (check-after-second-braket (str-handler "]" "" seed))) (else (loop (str-handler "]]" "" seed))))))) ((#\&) (let ((ent-ref (next-token-of (lambda (c) (and (not (eof-object? c)) (char-alphabetic? c) c)) port))) (cond ((and (string=? "gt" ent-ref) (eqv? (peek-char port) #\;)) (read-char port) (loop (str-handler fragment ">" seed))) (else (loop (str-handler ent-ref "" (str-handler fragment "&" seed))))))) (else (parser-error port "can't happen"))))))))

(define (SSAX:read-char-ref port) (let* ((base (cond ((eqv? (peek-char port) #\x) (read-char port) 16) (else 10))) (name (next-token '() '(#\;) "XML [66]" port)) (char-code (string->number name base))) (read-char port) (if (integer? char-code) (ascii->char char-code) (parser-error port "[wf-Legalchar] broken for '" name "'"))))

(define SSAX:predefined-parsed-entities `((,(string->symbol "amp") . "&") (,(string->symbol "lt") . "<") (,(string->symbol "gt") . ">") (,(string->symbol "apos") . "'") (,(string->symbol "quot") . "\"")))

(define (SSAX:handle-parsed-entity port name entities content-handler str-handler seed) (cond ((assq name entities) => (lambda (decl-entity) (let ((ent-body (cdr decl-entity)) (new-entities (cons (cons name #f) entities))) (cond ((string? ent-body) (call-with-input-string ent-body (lambda (port) (content-handler port new-entities seed)))) ((procedure? ent-body) (let ((port (ent-body))) (begin0 (content-handler port new-entities seed) (close-input-port port)))) (else (parser-error port "[norecursion] broken for " name)))))) ((assq name SSAX:predefined-parsed-entities) => (lambda (decl-entity) (str-handler (cdr decl-entity) "" seed))) (else (parser-error port "[wf-entdeclared] broken for " name))))

(define (make-empty-attlist) '())

(define (attlist-add attlist name-value) (if (null? attlist) (cons name-value attlist) (case (name-compare (car name-value) (caar attlist)) ((=) #f) ((<) (cons name-value attlist)) (else (cons (car attlist) (attlist-add (cdr attlist) name-value))))))

(define attlist-null? null?)

(define (attlist-remove-top attlist) (values (car attlist) (cdr attlist)))

(define (attlist->alist attlist) attlist)

(define attlist-fold fold)

(define *break-chars* (list #\newline #\return #\space #\tab #\< #\&))

(define SSAX:read-attributes (let () 
(define (read-attrib-value delimiter port entities prev-fragments) (let* ((new-fragments (cons (next-token '() (cons delimiter *break-chars*) "XML [10]" port) prev-fragments)) (cterm (read-char port))) (if (or (eof-object? cterm) (eqv? cterm delimiter)) new-fragments (case cterm ((#\newline #\space) (read-attrib-value delimiter port entities (cons " " new-fragments))) ((#\&) (cond ((eqv? (peek-char port) #\#) (read-char port) (read-attrib-value delimiter port entities (cons (string (SSAX:read-char-ref port)) new-fragments))) (else (read-attrib-value delimiter port entities (read-named-entity port entities new-fragments))))) ((#\<) (parser-error port "[CleanAttrVals] broken")) (else (parser-error port "Can't happen")))))) 
(define (read-named-entity port entities fragments) (let ((name (SSAX:read-NCName port))) (assert-curr-char '(#\;) "XML [68]" port) (SSAX:handle-parsed-entity port name entities (lambda (port entities fragments) (read-attrib-value '*eof* port entities fragments)) (lambda (str1 str2 fragments) (if (equal? "" str2) (cons str1 fragments) (cons* str2 str1 fragments))) fragments))) (lambda (port entities) (let loop ((attr-list (make-empty-attlist))) (if (not (SSAX:ncname-starting-char? (SSAX:skip-S port))) attr-list (let ((name (SSAX:read-QName port))) (SSAX:skip-S port) (assert-curr-char '(#\=) "XML [25]" port) (SSAX:skip-S port) (let ((delimiter (assert-curr-char '(#\' #\") "XML [10]" port))) (loop (or (attlist-add attr-list (cons name (apply string-append (reverse (read-attrib-value delimiter port entities '()))))) (parser-error port "[uniqattspec] broken for " name))))))))))

(define (SSAX:resolve-name port unres-name namespaces apply-default-ns?) 
  (cond 
   ((pair? unres-name) (cons (cond ((assq (car unres-name) namespaces) => cadr) ((eq? (car unres-name) SSAX:Prefix-XML) SSAX:Prefix-XML) (else (parser-error port "[nsc-NSDeclared] broken; prefix " (car unres-name)))) (cdr unres-name)))
   (apply-default-ns? (let ((default-ns (assq '*DEFAULT* namespaces))) (if (and default-ns (cadr default-ns)) (cons (cadr default-ns) unres-name) unres-name))) (else unres-name)))

(define (SSAX:uri-string->symbol uri-str) (string->symbol uri-str))

(define SSAX:complete-start-tag (let ((xmlns (string->symbol "xmlns")) (largest-dummy-decl-attr (list SSAX:largest-unres-name #f #f #f))) 
(define (validate-attrs port attlist decl-attrs) 
(define (add-default-decl decl-attr result) (let*-values (((attr-name content-type use-type default-value) (apply values decl-attr))) (and (eq? use-type 'REQUIRED) (parser-error port "[RequiredAttr] broken for" attr-name)) (if default-value (cons (cons attr-name default-value) result) result))) (let loop ((attlist attlist) (decl-attrs decl-attrs) (result '())) (if (attlist-null? attlist) (attlist-fold add-default-decl result decl-attrs) (let*-values (((attr attr-others) (attlist-remove-top attlist)) ((decl-attr other-decls) (if (attlist-null? decl-attrs) (values largest-dummy-decl-attr decl-attrs) (attlist-remove-top decl-attrs)))) (case (name-compare (car attr) (car decl-attr)) ((<) (if (or (eq? xmlns (car attr)) (and (pair? (car attr)) (eq? xmlns (caar attr)))) (loop attr-others decl-attrs (cons attr result)) (parser-error port "[ValueType] broken for " attr))) ((>) (loop attlist other-decls (add-default-decl decl-attr result))) (else (let*-values (((attr-name content-type use-type default-value) (apply values decl-attr))) (cond ((eq? use-type 'FIXED) (or (equal? (cdr attr) default-value) (parser-error port "[FixedAttr] broken for " attr-name))) ((eq? content-type 'CDATA) #t) ((pair? content-type) (or (member (cdr attr) content-type) (parser-error port "[enum] broken for " attr-name "=" (cdr attr)))) (else (SSAX:warn port "declared content type " content-type " not verified yet"))) (loop attr-others other-decls (cons attr result))))))))) 


(define (add-ns port prefix uri-str namespaces)
  (and (equal? "" uri-str) (parser-error port "[dt-NSName] broken for " prefix))
  (let ((uri-symbol (SSAX:uri-string->symbol uri-str))) (let loop ((nss namespaces)) (cond ((null? nss) (cons (cons* prefix uri-symbol uri-symbol) namespaces)) ((eq? uri-symbol (cddar nss)) (cons (cons* prefix (cadar nss) uri-symbol) namespaces)) (else (loop (cdr nss)))))))
 
(define (adjust-namespace-decl port attrs namespaces) (let loop ((attrs attrs) (proper-attrs '()) (namespaces namespaces)) (cond ((null? attrs) (values proper-attrs namespaces)) ((eq? xmlns (caar attrs)) (loop (cdr attrs) proper-attrs (if (equal? "" (cdar attrs)) (cons (cons* '*DEFAULT* #f #f) namespaces) (add-ns port '*DEFAULT* (cdar attrs) namespaces)))) ((and (pair? (caar attrs)) (eq? xmlns (caaar attrs))) (loop (cdr attrs) proper-attrs (add-ns port (cdaar attrs) (cdar attrs) namespaces))) (else (loop (cdr attrs) (cons (car attrs) proper-attrs) namespaces))))) (lambda (tag-head port elems entities namespaces) (let*-values (((attlist) (SSAX:read-attributes port entities)) ((empty-el-tag?) (begin (SSAX:skip-S port) (and (eqv? #\/ (assert-curr-char '(#\> #\/) "XML [40], XML [44], no '>'" port)) (assert-curr-char '(#\>) "XML [44], no '>'" port)))) ((elem-content decl-attrs) (if elems (cond ((assoc tag-head elems) => (lambda (decl-elem) (values (if empty-el-tag? 'EMPTY-TAG (cadr decl-elem)) (caddr decl-elem)))) (else (parser-error port "[elementvalid] broken, no decl for " tag-head))) (values (if empty-el-tag? 'EMPTY-TAG 'ANY) #f))) ((merged-attrs) (if decl-attrs (validate-attrs port attlist decl-attrs) (attlist->alist attlist))) ((proper-attrs namespaces) (adjust-namespace-decl port merged-attrs namespaces))) (values (SSAX:resolve-name port tag-head namespaces #t) (fold-right (lambda (name-value attlist) (or (attlist-add attlist (cons (SSAX:resolve-name port (car name-value) namespaces #f) (cdr name-value))) (parser-error port "[uniqattspec] after NS expansion broken for " name-value))) (make-empty-attlist) proper-attrs) namespaces elem-content)))))

(define (SSAX:read-external-ID port) (let ((discriminator (SSAX:read-NCName port))) (assert-curr-char SSAX:S-chars "space after SYSTEM or PUBLIC" port) (SSAX:skip-S port) (let ((delimiter (assert-curr-char '(#\' #\") "XML [11], XML [12]" port))) (cond ((eq? discriminator (string->symbol "SYSTEM")) (begin0 (next-token '() (list delimiter) "XML [11]" port) (read-char port))) ((eq? discriminator (string->symbol "PUBLIC")) (skip-until (list delimiter) port) (assert-curr-char SSAX:S-chars "space after PubidLiteral" port) (SSAX:skip-S port) (let* ((delimiter (assert-curr-char '(#\' #\") "XML [11]" port)) (systemid (next-token '() (list delimiter) "XML [11]" port))) (read-char port) systemid)) (else (parser-error port "XML [75], " discriminator " rather than SYSTEM or PUBLIC"))))))

(define (SSAX:scan-Misc port) (let loop ((c (SSAX:skip-S port))) (cond ((eof-object? c) c) ((not (char=? c #\<)) (parser-error port "XML [22], char '" c "' unexpected")) (else (let ((token (SSAX:read-markup-token port))) (case (xml-token-kind token) ((COMMENT) (loop (SSAX:skip-S port))) ((PI DECL START) token) (else (parser-error port "XML [22], unexpected token of kind " (xml-token-kind token)))))))))

(define SSAX:read-char-data (let ((terminators-usual '(#\< #\&)) (terminators-usual-eof '(#\< *eof* #\&)) (handle-fragment (lambda (fragment str-handler seed) (if (string-null? fragment) seed (str-handler fragment "" seed))))) (lambda (port expect-eof? str-handler seed) (if (eqv? #\< (peek-char port)) (let ((token (SSAX:read-markup-token port))) (case (xml-token-kind token) ((START END) (values seed token)) ((CDSECT) (let ((seed (SSAX:read-CDATA-body port str-handler seed))) (SSAX:read-char-data port expect-eof? str-handler seed))) ((COMMENT) (SSAX:read-char-data port expect-eof? str-handler seed)) (else (values seed token)))) (let ((char-data-terminators (if expect-eof? terminators-usual-eof terminators-usual))) (let loop ((seed seed)) (let* ((fragment (next-token '() char-data-terminators "reading char data" port)) (term-char (peek-char port))) (if (eof-object? term-char) (values (handle-fragment fragment str-handler seed) term-char) (case term-char ((#\<) (let ((token (SSAX:read-markup-token port))) (case (xml-token-kind token) ((CDSECT) (loop (SSAX:read-CDATA-body port str-handler (handle-fragment fragment str-handler seed)))) ((COMMENT) (loop (handle-fragment fragment str-handler seed))) (else (values (handle-fragment fragment str-handler seed) token))))) ((#\&) (case (peek-next-char port) ((#\#) (read-char port) (loop (str-handler fragment (string (SSAX:read-char-ref port)) seed))) (else (let ((name (SSAX:read-NCName port))) (assert-curr-char '(#\;) "XML [68]" port) (values (handle-fragment fragment str-handler seed) (make-xml-token 'ENTITY-REF name)))))) (else (if (eqv? (peek-next-char port) #\newline) (read-char port)) (loop (str-handler fragment (string #\newline) seed))))))))))))

(define (SSAX:assert-token token kind gi error-cont) (or (and (xml-token? token) (eq? kind (xml-token-kind token)) (equal? gi (xml-token-head token))) (error-cont token kind gi)))

(define SSAX:make-pi-parser (lambda (pi-handlers) (lambda (port target seed) (let loop ((pi-handlers pi-handlers) (default #f)) (cond ((null? pi-handlers) (if default (default port target seed) (begin (SSAX:warn port (string-append nl "Skipping PI: ") target nl) (SSAX:skip-pi port) seed))) ((eq? '*DEFAULT* (caar pi-handlers)) (loop (cdr pi-handlers) (cdar pi-handlers))) ((eq? (caar pi-handlers) default) ((cdar pi-handlers) port target seed)) (else (loop (cdr pi-handlers) default)))))))

(define SSAX:make-elem-parser (lambda (my-new-level-seed my-finish-element my-char-data-handler my-pi-handlers) (lambda (start-tag-head port elems entities namespaces preserve-ws? seed) 
(define xml-space-gi (cons SSAX:Prefix-XML (string->symbol "space"))) (let handle-start-tag ((start-tag-head start-tag-head) (port port) (entities entities) (namespaces namespaces) (preserve-ws? preserve-ws?) (parent-seed seed)) (let*-values (((elem-gi attributes namespaces expected-content) (SSAX:complete-start-tag start-tag-head port elems entities namespaces)) ((seed) (my-new-level-seed elem-gi attributes namespaces expected-content parent-seed))) (case expected-content ((EMPTY-TAG) (my-finish-element elem-gi attributes namespaces parent-seed seed)) ((EMPTY) (SSAX:assert-token (and (eqv? #\< (SSAX:skip-S port)) (SSAX:read-markup-token port)) 'END start-tag-head (lambda (token exp-kind exp-head) (parser-error port "[elementvalid] broken for " token " while expecting " exp-kind exp-head))) (my-finish-element elem-gi attributes namespaces parent-seed seed)) (else (let ((preserve-ws? (cond ((assoc xml-space-gi attributes) => (lambda (name-value) (equal? "preserve" (cdr name-value)))) (else preserve-ws?)))) (let loop ((port port) (entities entities) (expect-eof? #f) (seed seed)) (let*-values (((seed term-token) (SSAX:read-char-data port expect-eof? my-char-data-handler seed))) (if (eof-object? term-token) seed (case (xml-token-kind term-token) ((END) (SSAX:assert-token term-token 'END start-tag-head (lambda (token exp-kind exp-head) (parser-error port "[GIMatch] broken for " term-token " while expecting " exp-kind exp-head))) (my-finish-element elem-gi attributes namespaces parent-seed seed)) ((PI) (let ((seed ((SSAX:make-pi-parser my-pi-handlers) port (xml-token-head term-token) seed))) (loop port entities expect-eof? seed))) ((ENTITY-REF) (let ((seed (SSAX:handle-parsed-entity port (xml-token-head term-token) entities (lambda (port entities seed) (loop port entities #t seed)) my-char-data-handler seed))) (loop port entities expect-eof? seed))) ((START) (if (eq? expected-content 'PCDATA) (parser-error port "[elementvalid] broken for " elem-gi " with char content only; unexpected token " term-token)) (let ((seed (handle-start-tag (xml-token-head term-token) port entities namespaces preserve-ws? seed))) (loop port entities expect-eof? seed))) (else (parser-error port "XML [43] broken for " term-token))))))))))))))

(define SSAX:make-parser (lambda user-handlers 
(define all-handlers `((DOCTYPE . ,(lambda (port docname systemid internal-subset? seed) (when internal-subset? (SSAX:warn port "Internal DTD subset is not currently handled ") (SSAX:skip-internal-dtd port)) (SSAX:warn port "DOCTYPE DECL " docname " " systemid " found and skipped") (values #f '() '() seed))) (UNDECL-ROOT . ,(lambda (elem-gi seed) (values #f '() '() seed))) (DECL-ROOT . ,(lambda (elem-gi seed) seed)) (NEW-LEVEL-SEED . REQD) (FINISH-ELEMENT . REQD) (CHAR-DATA-HANDLER . REQD) (PI))) 
(define (delete-assoc alist tag cont) (let loop ((alist alist) (scanned '())) (cond ((null? alist) (error "Unknown user-handler-tag: " tag)) ((eq? tag (caar alist)) (cont tag (cdar alist) (append scanned (cdr alist)))) (else (loop (cdr alist) (cons (car alist) scanned)))))) 
(define (merge-handlers declared-handlers given-handlers) (cond ((null? given-handlers) (cond ((null? declared-handlers) '()) ((not (eq? 'REQD (cdar declared-handlers))) (cons (car declared-handlers) (merge-handlers (cdr declared-handlers) given-handlers))) (else (error "The handler for the tag " (caar declared-handlers) " must be specified")))) ((null? (cdr given-handlers)) (error "Odd number of arguments to SSAX:make-parser")) (else (delete-assoc declared-handlers (car given-handlers) (lambda (tag value alist) (cons (cons tag (cadr given-handlers)) (merge-handlers alist (cddr given-handlers)))))))) (let ((user-handlers (merge-handlers all-handlers user-handlers))) 
(define (get-handler tag) (cond ((assq tag user-handlers) => cdr) (else (error "unknown tag: " tag)))) (lambda (port seed) 
(define (handle-decl port token-head seed) (or (eq? (string->symbol "DOCTYPE") token-head) (parser-error port "XML [22], expected DOCTYPE declaration, found " token-head)) (assert-curr-char SSAX:S-chars "XML [28], space after DOCTYPE" port) (SSAX:skip-S port) (let*-values (((docname) (SSAX:read-QName port)) ((systemid) (and (SSAX:ncname-starting-char? (SSAX:skip-S port)) (SSAX:read-external-ID port))) ((internal-subset?) (begin (SSAX:skip-S port) (eqv? #\[ (assert-curr-char '(#\> #\[) "XML [28], end-of-DOCTYPE" port)))) ((elems entities namespaces seed) ((get-handler 'DOCTYPE) port docname systemid internal-subset? seed))) (scan-for-significant-prolog-token-2 port elems entities namespaces seed))) 
(define (scan-for-significant-prolog-token-1 port seed)
  (let ((token (SSAX:scan-Misc port)))
    (if (eof-object? token)
        (parser-error port "XML [22], unexpected EOF")
        (case (xml-token-kind token)
          ((PI) (let ((seed ((SSAX:make-pi-parser (get-handler 'PI)) port (xml-token-head token) seed))) (scan-for-significant-prolog-token-1 port seed)))
          ((DECL) (handle-decl port (xml-token-head token) seed))
          ((START) 
           (let*-values (((elems entities namespaces seed) 
                          ((get-handler 'UNDECL-ROOT) (xml-token-head token) seed))) 
             (element-parser (xml-token-head token) port elems entities namespaces #f seed)))
          (else (parser-error port "XML [22], unexpected markup " token)))))) 
(define (scan-for-significant-prolog-token-2 port elems entities namespaces seed) (let ((token (SSAX:scan-Misc port))) (if (eof-object? token) (parser-error port "XML [22], unexpected EOF") (case (xml-token-kind token) ((PI) (let ((seed ((SSAX:make-pi-parser (get-handler 'PI)) port (xml-token-head token) seed))) (scan-for-significant-prolog-token-2 port elems entities namespaces seed))) ((START) (element-parser (xml-token-head token) port elems entities namespaces #f ((get-handler 'DECL-ROOT) (xml-token-head token) seed))) (else (parser-error port "XML [22], unexpected markup " token)))))) 
(define element-parser (SSAX:make-elem-parser (get-handler 'NEW-LEVEL-SEED) (get-handler 'FINISH-ELEMENT) (get-handler 'CHAR-DATA-HANDLER) (get-handler 'PI))) (scan-for-significant-prolog-token-1 port seed)))))

(define (SSAX:XML->SXML port namespace-prefix-assig) 
  (letrec ((namespaces (map (lambda (el) (cons* #f (car el) (SSAX:uri-string->symbol (cdr el)))) namespace-prefix-assig)) (RES-NAME->SXML (lambda (res-name) (string->symbol (string-append (symbol->string (car res-name)) ":" (symbol->string (cdr res-name)))))) (reverse-collect-str (lambda (fragments) (if (null? fragments) '() (let loop ((fragments fragments) (result '()) (strs '())) (cond ((null? fragments) (if (null? strs) result (cons (apply string-append strs) result))) ((string? (car fragments)) (loop (cdr fragments) result (cons (car fragments) strs))) (else (loop (cdr fragments) (cons (car fragments) (if (null? strs) result (cons (apply string-append strs) result))) '()))))))) (reverse-collect-str-drop-ws (lambda (fragments) (cond ((null? fragments) '()) ((and (string? (car fragments)) (null? (cdr fragments)) (string-whitespace? (car fragments))) '()) (else (let loop ((fragments fragments) (result '()) (strs '()) (all-whitespace? #t)) (cond ((null? fragments) (if all-whitespace? result (cons (apply string-append strs) result))) ((string? (car fragments)) (loop (cdr fragments) result (cons (car fragments) strs) (and all-whitespace? (string-whitespace? (car fragments))))) (else (loop (cdr fragments) (cons (car fragments) (if all-whitespace? result (cons (apply string-append strs) result))) '() #t)))))))))
    (let ((result (reverse ((SSAX:make-parser 'NEW-LEVEL-SEED (lambda (elem-gi attributes namespaces expected-content seed) '()) 'FINISH-ELEMENT (lambda (elem-gi attributes namespaces parent-seed seed) (let ((seed (reverse-collect-str-drop-ws seed)) (attrs (attlist-fold (lambda (attr accum) (cons (list (if (symbol? (car attr)) (car attr) (RES-NAME->SXML (car attr))) (cdr attr)) accum)) '() attributes))) (cons (cons (if (symbol? elem-gi) elem-gi (RES-NAME->SXML elem-gi)) (if (null? attrs) seed (cons (cons '@ attrs) seed))) parent-seed))) 'CHAR-DATA-HANDLER (lambda (string1 string2 seed) (if (string-null? string2) (cons string1 seed) (cons* string2 string1 seed))) 'DOCTYPE (lambda (port docname systemid internal-subset? seed) (when internal-subset? (SSAX:warn port "Internal DTD subset is not currently handled ") (SSAX:skip-internal-dtd port)) (SSAX:warn port "DOCTYPE DECL " docname " " systemid " found and skipped") (values #f '() namespaces seed)) 'UNDECL-ROOT (lambda (elem-gi seed) (values #f '() namespaces seed)) 'PI `((*DEFAULT* . ,(lambda (port pi-tag seed) (cons (list '*PI* pi-tag (SSAX:read-pi-body-as-string port)) seed))))) port '())))) (cons '*TOP* (if (null? namespace-prefix-assig) result (cons (cons '*NAMESPACES* (map (lambda (ns) (list (car ns) (cdr ns))) namespace-prefix-assig)) result))))))
