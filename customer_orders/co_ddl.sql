PROMPT creating tables 
create table customers (
  customer_id     integer generated by default on null as identity 
                  constraint customers_pk primary key,
  email_address   varchar2(255 char) not null
                  constraint customers_email_u unique,
  full_name       varchar2(255 char) not null
)
;

comment on table customers
  is 'Details of the people placing orders';

comment on column customers.customer_id 
  is 'Auto-incrementing primary key';
  
comment on column customers.email_address 
  is 'The email address the person uses to access the account';
  
comment on column customers.full_name
  is 'What this customer is called';

create table stores (
  store_id          integer 
                    generated by default on null as identity 
                    constraint stores_pk 
                    primary key,
  store_name        varchar2(255 char) 
                    constraint store_name_u 
                    unique
                    not null,
  web_address       varchar2(100 char),
  physical_address  varchar2(512 char),
  latitude          number,
  longitude         number,
  logo              blob,
  logo_mime_type    varchar2(512 char),
  logo_filename     varchar2(512 char),
  logo_charset      varchar2(512 char),
  logo_last_updated date,
  constraint store_at_least_one_address_c 
  check ( 
    coalesce ( web_address, physical_address ) is not null 
  )
)
;

comment on table stores
  is 'Physical and virtual locations where people can purchase products';

comment on column stores.store_id 
  is 'Auto-incrementing primary key';
  
comment on column stores.store_name 
  is 'What the store is called';
  
comment on column stores.web_address
  is 'The URL of a virtual store';
  
comment on column stores.physical_address
  is 'The postal address of this location';
  
comment on column stores.latitude
  is 'The north-south position of a physical store';
  
comment on column stores.longitude
  is 'The east-west position of a physical store';
  
comment on column stores.logo
  is 'An image used by this store';
  
comment on column stores.logo_mime_type 
  is 'The mime-type of the store logo';
  
comment on column stores.logo_last_updated 
  is 'The date the image was last changed';
  
comment on column stores.logo_filename 
  is 'The name of the file loaded in the image column';
  
comment on column stores.logo_charset 
  is 'The character set used to encode the image';

create table products (
  product_id         integer 
                     generated by default on null as identity 
                     constraint products_pk primary key,
  product_name       varchar2(255 char) not null,
  unit_price         number(10,2),
  product_details    blob
                     constraint products_json_c
                     check ( product_details is json ),
  product_image      blob,
  image_mime_type    varchar2(512 char),
  image_filename     varchar2(512 char),
  image_charset      varchar2(512 char),
  image_last_updated date
)
;

comment on table products
  is 'Details of goods that customers can purchase';

comment on column products.product_id 
  is 'Auto-incrementing primary key';
  
comment on column products.unit_price 
  is 'The monetary value of one item of this product';
  
comment on column products.product_details 
  is 'Further details of the product stored in JSON format';
  
comment on column products.product_image 
  is 'A picture of the product';
  
comment on column products.image_mime_type 
  is 'The mime-type of the product image';
  
comment on column products.image_last_updated 
  is 'The date the image was last changed';
  
comment on column products.image_filename 
  is 'The name of the file loaded in the image column';
  
comment on column products.image_charset 
  is 'The character set used to encode the image';
  
comment on column products.product_name 
  is 'What a product is called';

create table orders (
  order_id        integer 
                  generated by default on null as identity
                  constraint orders_pk primary key,
  order_datetime  timestamp not null,
  customer_id     integer
                  constraint orders_customer_id_fk
                  references customers 
                  not null,
  order_status    varchar2(10 char) 
                  constraint orders_status_c
                  check ( order_status in 
                    ( 'CANCELLED','COMPLETE','OPEN','PAID','REFUNDED','SHIPPED')
                  ) 
                  not null,
  store_id        integer
                  constraint orders_store_id_fk
                  references stores 
                  not null
)
;

comment on table orders
  is 'Details of who made purchases where';

comment on column orders.order_id 
  is 'Auto-incrementing primary key';
  
comment on column orders.order_datetime 
  is 'When the order was placed';
  
comment on column orders.customer_id 
  is 'Who placed this order';
  
comment on column orders.store_id 
  is 'Where this order was placed';
  
comment on column orders.order_status 
  is 'What state the order is in. Valid values are:
OPEN - the order is in progress
PAID - money has been received from the customer for this order
SHIPPED - the products have been dispatched to the customer
COMPLETE - the customer has received the order
CANCELLED - the customer has stopped the order
REFUNDED - there has been an issue with the order and the money has been returned to the customer';

create table order_items (
  order_id                   integer 
                             constraint order_items_order_id_fk
                             references orders,
  line_item_id               integer,
  product_id                 integer
                             constraint order_items_product_id_fk
                             references products 
                             not null,
  unit_price                 number(10,2) not null,
  quantity                   integer not null,
  constraint order_items_pk  primary key ( order_id, line_item_id ),
  constraint order_items_product_u unique ( product_id, order_id )
)
;

comment on table order_items
  is 'Details of which products the customer has purchased in an order';

comment on column order_items.order_id 
  is 'The order these products belong to';

comment on column order_items.line_item_id 
  is 'An incrementing number, starting at one for each order';

comment on column order_items.product_id 
  is 'Which item was purchased';
  
comment on column order_items.unit_price 
  is 'How much the customer paid for one item of the product';
  
comment on column order_items.quantity 
  is 'How many items of this product the customer purchased';
  

PROMPT Creating indexes

create index customers_name_i on customers ( full_name );
create index orders_customer_id_i on orders ( customer_id );
create index orders_store_id_i on orders ( store_id );

PROMPT Creating views
create or replace view customer_order_products as 
  select o.order_id, o.order_datetime, o.order_status, 
         c.customer_id, c.email_address, c.full_name, 
         sum ( oi.quantity * oi.unit_price ) order_total,
         listagg (
           p.product_name, ', ' 
           on overflow truncate '...' with count
         ) within group ( order by oi.line_item_id ) items
  from   orders o
  join   order_items oi
  on     o.order_id = oi.order_id
  join   customers c
  on     o.customer_id = c.customer_id
  join   products p
  on     oi.product_id = p.product_id
  group  by o.order_id, o.order_datetime, o.order_status, 
         c.customer_id, c.email_address, c.full_name;
         
comment on table customer_order_products
  is 'A summary of who placed each order and what they bought';
  
comment on column customer_order_products.order_id 
  is 'The primary key of the order';
  
comment on column customer_order_products.order_datetime 
  is 'The date and time the order was placed';
  
comment on column customer_order_products.order_status 
  is 'The current state of this order';
  
comment on column customer_order_products.customer_id 
  is 'The primary key of the customer';
  
comment on column customer_order_products.email_address 
  is 'The email address the person uses to access the account';
  
comment on column customer_order_products.full_name 
  is 'What this customer is called';
  
comment on column customer_order_products.order_total 
  is 'The total amount the customer paid for the order';
  
comment on column customer_order_products.items 
  is 'A comma-separated list naming the products in this order';
         
create or replace view store_orders as 
  select case
           grouping_id ( store_name, order_status ) 
           when 1 then 'STORE TOTAL'
           when 2 then 'STATUS TOTAL'
           when 3 then 'GRAND TOTAL'
         end total,
         s.store_name, 
         coalesce ( s.web_address, s.physical_address ) address,
         s.latitude, s.longitude,
         o.order_status,
         count ( distinct o.order_id ) order_count,
         sum ( oi.quantity * oi.unit_price ) total_sales
  from   stores s
  join   orders o
  on     s.store_id = o.store_id
  join   order_items oi
  on     o.order_id = oi.order_id
  group  by grouping sets ( 
    ( s.store_name, coalesce ( s.web_address, s.physical_address ), s.latitude, s.longitude ),
    ( s.store_name, coalesce ( s.web_address, s.physical_address ), s.latitude, s.longitude, o.order_status ),
    o.order_status, 
    ()
  );
  
comment on table store_orders
  is 'A summary of what was purchased at each location, including summaries each store, order status and overall total';
   
comment on column store_orders.order_status 
  is 'The current state of this order';
  
comment on column store_orders.total 
  is 'Indicates what type of total is displayed, including Store, Status, or Grand Totals';
  
comment on column store_orders.store_name 
  is 'What the store is called';
  
comment on column store_orders.latitude
  is 'The north-south position of a physical store';
  
comment on column store_orders.longitude
  is 'The east-west position of a physical store';
  
comment on column store_orders.address 
  is 'The physical or virtual location of this store';
  
comment on column store_orders.total_sales 
  is 'The total value of orders placed';
  
comment on column store_orders.order_count 
  is 'The total number of orders placed';
  
create or replace view product_reviews as   
  select p.product_name, r.rating, 
         round ( 
           avg ( r.rating ) over (
             partition by product_name
           ),
           2
         ) avg_rating,
         r.review
  from   products p,
         json_table (
           p.product_details, '$'
           columns ( 
             nested path '$.reviews[*]'
             columns (
               rating integer path '$.rating',
               review varchar2(4000) path '$.review'
             )
           )
         ) r;
         
comment on table product_reviews
  is 'A relational view of the reviews stored in the JSON for each product';
  
comment on column product_reviews.product_name 
  is 'What this product is called';
  
comment on column product_reviews.rating 
  is 'The review score the customer has placed. Range is 1-10';
    
comment on column product_reviews.avg_rating 
  is 'The mean of the review scores for this product';

comment on column product_reviews.review 
  is 'The text of the review';
         
create or replace view product_orders as 
  select p.product_name, o.order_status, 
         sum ( oi.quantity * oi.unit_price ) total_sales,
         count (*) order_count
  from   orders o
  join   order_items oi
  on     o.order_id = oi.order_id
  join   customers c
  on     o.customer_id = c.customer_id
  join   products p
  on     oi.product_id = p.product_id
  group  by p.product_name, o.order_status;  
  
comment on table product_orders
  is 'A summary of the state of the orders placed for each product';
  
comment on column product_orders.product_name 
  is 'What this product is called';
  
comment on column product_orders.order_status 
  is 'The current state of these order';
  
comment on column product_orders.total_sales 
  is 'The total value of orders placed';
  
comment on column product_orders.order_count 
  is 'The total number of orders placed';