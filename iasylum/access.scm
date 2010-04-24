;;; Code by Igor Hjelmstrom Vinhas Ribeiro - this is licensed under GNU GPL v2.

(require-extension (lib iasylum/jcode))

(module iasylum/access
  (open-access-db get-table-names get-table get-table-columns)

  (define (open-access-db fname)
    (j "com.healthmarketscience.jackcess.Database.open(new File(fname));" `((fname ,(->jstring fname)))))
  
  (define (get-table-names db) (iterable->list (j "db.getTableNames();" `((db ,db))) (lambda (v) (->string v))))
  
  (define (get-table db name)
    (let ((result (j "db.getTable(name);" `((name ,(->jstring name))(db ,db)))))
      (if (java-null? result) #f
          result)))
  
  (define (get-table-columns table) (iterable->list (j "table.getColumns();" `((table ,table))) )))