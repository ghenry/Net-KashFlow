package Net::KashFlow;
use Carp qw/croak/;
use warnings;
use strict;
use Net::KashFlowAPI;    # Autogenerated SOAP::Lite stubs

=head1 NAME

Net::KashFlow - Interact with KashFlow accounting web service

=head1 SYNOPSIS

    my $kf = Net::KashFlow->new(username => $u, password => $p);

    my $c = $kf->get_customer($cust_email);
    my $i = $kf->create_invoice({
        InvoiceNumber => time, CustomerID => $c->CustomerID
    });

    $i->add_line({ Quantity => 1, Description => "Widgets", Rate => 100 })

    $i->pay({ PayAmount => 100 });

=head1 WARNING

This module is incomplete. It does not implement all of the KashFlow
API. Please find the github repository at
http://github.com/simoncozens/Net-KashFlow and send me pull requests for
your newly-implemented features. Thank you.

=head1 METHODS

=head2 new

Simple constructor - requires "username" and "password" named
parameters.

=cut

# VERSION: generated by DZP::OurPkgVersion

sub new {
    my ( $self, %args ) = @_;
    for (qw/username password/) {
        croak("You need to pass a '$_'") unless $args{$_};
    }
    bless {%args}, $self;
}

sub _c {
    my ( $self, $method, @args ) = @_;
    my ( $result, $status, $explanation ) =
      KashFlowAPI->$method( $self->{username}, $self->{password}, @args );
    if ($explanation) { croak($explanation) }
    return $result;
}

=head2 get_supplier($id)

Returns a Net::KashFlow::Supplier object for the supplier

=cut

sub get_supplier {
    my ( $self, $thing, $by_id ) = @_;
    my $method = "GetSupplier";
    if ($by_id) { $method .= "ByID" }
    my $supplier;
    eval { $supplier = $self->_c( $method, $thing ) };
    die $@ . "\n" if $@;
    return 0 unless $supplier->{SupplierID};
    $supplier = bless $supplier, "Net::KashFlow::Supplier";
    $supplier->{kf} = $self;
    return $supplier;
}

=head2 get_supplier_by_id($id)

Returns the Net::KashFlow::Supplier object as specified by the ID

=cut

sub get_supplier_by_id { $_[0]->get_supplier( $_[1], 1 ) }

=head2 get_customer($id | $email)

Returns a Net::KashFlow::Customer object for the given customer. If the
parameter passed has an C<@> sign then this is treated as an email
address and the customer looked up email address; otherwise the
customer is looked up by customer code. If no customer is found in the
database, nothing is returned.

=cut

sub get_customer {
    my ( $self, $thing, $by_id ) = @_;
    my $method = "GetCustomer";
    if ( $thing =~ /@/ ) { $method .= "ByEmail" }
    if ($by_id)          { $method .= "ByID" }
    my $customer;
    eval { $customer = $self->_c( $method, $thing ) };
    if ( $@ =~ /no customer/ ) { return }
    die $@ . "\n" if $@;
    $customer = bless $customer, "Net::KashFlow::Customer";
    $customer->{kf} = $self;
    return $customer;
}

=head2 get_customer_by_id($internal_id)

Like C<get_customer>, but works on the internal ID of the customer.

=cut

sub get_customer_by_id { $_[0]->get_customer( $_[1], 1 ) }

=head2 get_customers

Returns all customers

=cut

sub get_customers {
    my $self = shift;
    return
      map { $_->{kf} = $self; bless $_, "Net::KashFlow::Customer" }
      @{ $self->_c("GetCustomers")->{Customer} };
}

=head2 create_customer({ Name => "...", Address => "...", ... });

Inserts a new customer into the database, returning a
Net::KashFlow::Customer object.

=cut

sub create_customer {
    my ( $self, $data ) = @_;
    my $id = $self->_c( "InsertCustomer", $data );
    return $self->get_customer_by_id($id);
}

=head2 get_invoice($your_id)

=head2 get_invoice_by_id($internal_id)

Returns a Net::KashFlow::Invoice object representing the invoice.

=cut

sub get_invoice {
    my ( $self, $thing, $by_id ) = @_;
    my $method = "GetInvoice";
    if ($by_id) { $method .= "ByID" }
    my $invoice;
    eval { $invoice = $self->_c( $method, $thing ) };
    if ( $@ =~ /no invoice/ ) { return }
    die $@ . "\n" if $@;
    return unless $invoice->{InvoiceNumber};
    $invoice = bless $invoice, "Net::KashFlow::Invoice";
    $invoice->{kf} = $self;
    $invoice->{Lines} = bless $invoice->{Lines}, "InvoiceLineSet";    # Urgh
    return $invoice;
}
sub get_invoice_by_id { $_[0]->get_invoice( $_[1], 1 ) }

=head2 get_invoice_pdf($id)

Returns the URI for a PDF of the specified invoice

=cut

sub get_invoice_pdf {
    my ( $self, $id ) = @_;
    my $i = $self->get_invoice($id);
    return unless $i;
    my $uri = undef;
    eval { $uri = $self->_c( "PrintInvoice", $id ) };
    die $@ . "\n" if $@;
    return $uri;
}

=head2 get_invoice_paypal_link($id)

Returns a Paypal payment link for the specified invoice ID.

=cut

sub get_invoice_paypal_link {
    my ( $self, $id ) = @_;
    my $i = $self->get_invoice($id);
    return unless $i;
    my $uri = undef;
    eval { $uri = $self->_c( "GetPaypalLink", $id ) };
    die $@ . "\n" if $@;
    return $uri;
}

=head2 get_overdue_invoices

Returns an array of overdue invoices. Each element is a
Net::KashFlow::Invoice object

=cut

sub get_overdue_invoices {
    my ($self) = @_;
    my $invoices = undef;
    eval { $invoices = $self->_c("GetInvoices_Overdue") };
    die $@ . "\n" if $@;
    my @invoices = ();
    if ( ref $invoices->{Invoice} eq 'ARRAY' ) {
        for my $i ( @{ $invoices->{Invoice} } ) {
            $i = bless $i, "Net::KashFlow::Invoice";
            $i->{kf} = $self;
            $i->{Lines} = bless $i->{Lines}, "InvoiceLineSet";
            push @invoices, $i;
        }
    }
    else {
        my $i = $invoices->{Invoice};
        return unless $i->{InvoiceNumber};
        $i = bless $i, "Net::KashFlow::Invoice";
        $i->{kf} = $self;
        $i->{Lines} = bless $i->{Lines}, "InvoiceLineSet";
        push @invoices, $i;
    }
    return @invoices;
}

=head2 get_unpaid_invoices

Returns an array of unpaid invoices. Each element is a
Net::KashFlow::Invoice object

=cut

sub get_unpaid_invoices {
    my ($self) = @_;
    my $invoices = undef;
    eval { $invoices = $self->_c("GetInvoices_Unpaid") };
    die $@ . "\n" if $@;
    my @invoices = ();
    if ( ref $invoices->{Invoice} eq 'ARRAY' ) {
        for my $i ( @{ $invoices->{Invoice} } ) {
            $i = bless $i, "Net::KashFlow::Invoice";
            $i->{kf} = $self;
            $i->{Lines} = bless $i->{Lines}, "InvoiceLineSet";
            push @invoices, $i;
        }
    }
    else {
        my $i = $invoices->{Invoice};
        return unless $i->{InvoiceNumber};
        $i = bless $i, "Net::KashFlow::Invoice";
        $i->{kf} = $self;
        $i->{Lines} = bless $i->{Lines}, "InvoiceLineSet";
        push @invoices, $i;
    }
    return @invoices;
}

=head2 get_invoices_for_customer($customerID)

Returns an array containing all of the invoices for the specified customer

=cut

sub get_invoices_for_customer {
    my ( $self, $customer ) = @_;
    my $c = $self->get_customer_by_id($customer);
    die "No such customer" unless $c;
    my $invoices = ();
    eval { $invoices = $self->_c( "GetInvoicesForCustomer", $customer ) };
    die $@ . "\n" if $@;
    my @invoices = ();
    if ( ref $invoices->{Invoice} eq 'ARRAY' ) {

        for my $i ( @{ $invoices->{Invoice} } ) {
            $i = bless $i, "Net::KashFlow::Invoice";
            $i->{kf} = $self;
            $i->{Lines} = bless $i->{Lines}, "InvoiceLineSet";
            push @invoices, $i;
        }
    }
    else {
        my $i = $invoices->{Invoice};
        return unless $i->{InvoiceNumber};
        $i = bless $i, "Net::KashFlow::Invoice";
        $i->{kf} = $self;
        $i->{Lines} = bless $i->{Lines}, "InvoiceLineSet";
        push @invoices, $i;
    }
    return @invoices;
}

=head2 create_invoice({ ... })

=cut

sub create_invoice {
    my ( $self, $data ) = @_;
    my $id = $self->_c( "InsertInvoice", $data );
    return $self->get_invoice($id);
}

=head2 delete_invoice($invoice_id)

Delete an invoice. Returns true if invoice deleted

=cut

sub delete_invoice {
    my ( $self, $data ) = @_;
    my $invoice = $self->get_invoice($data);
    return 0 if !$invoice;
    eval { $self->_c( "DeleteInvoice", $data ) };
    die $@ . "\n" if $@;
    $invoice = undef;
    $invoice = $self->get_invoice($data);
    return 0 if $invoice->{InvoiceNumber};
    return 1;
}

=head2 get_receipt($id)

Returns a Net::KashFlow::Receipt object representing the receipt

=cut

sub get_receipt {
    my ( $self, $thing, $by_id ) = @_;
    my $method = "GetReceipt";
    if ($by_id) { $method .= "ByID" }
    my $receipt;
    eval { $receipt = $self->_c( $method, $thing ) };
    if ( $@ =~ /no receipt/ ) { return }
    die $@ . "\n" if $@;
    return unless $receipt->{InvoiceNumber};
    $receipt = bless $receipt, "Net::KashFlow::Receipt";
    $receipt->{kf} = $self;
    $receipt->{Lines} = bless $receipt->{Lines}, "InvoiceLineSet";    # Urgh
    return $receipt;
}

=head2 get_receipt_by_id($id)

Returns a Net::KashFlow::Receipt object representing the receipt but
by ID

=cut

sub get_receipt_by_id { $_[0]->get_receipt( $_[1], 1 ) }

=head2 get_receipts_for_supplier($id)

Returns an array containing all receipts for the specified supplier.

=cut

sub get_receipts_for_supplier {
    my ( $self, $id ) = @_;
    my $s = $self->get_supplier_by_id($id);
    die "No such supplier" unless $s;
    my $rs = ();
    eval { $rs = $self->_c( "GetReceiptsForSupplier", $s->SupplierID ) };
    die $@ . "\n" if $@;
    my @rs = ();
    if ( ref $rs->{Invoice} eq 'ARRAY' ) {

        for my $r ( @{ $rs->{Invoice} } ) {
            $r = bless $r, "Net::KashFlow::Receipt";
            $r->{kf} = $self;
            $r->{Lines} = bless $r->{Lines}, "InvoiceLineSet";
            push @rs, $r;
        }
    }
    else {
        my $r = $rs->{Invoice};
        return unless $r->{InvoiceNumber};
        $r = bless $r, "Net::KashFlow::Receipt";
        $r->{kf} = $self;
        $r->{Lines} = bless $r->{Lines}, "InvoiceLineSet";
        push @rs, $r;
    }
    return @rs;
}

=head2 create_receipt ({ ... })

Create a new receipt. For details, see

http://accountingapi.com/manual_methods_InsertReceipt.asp

Returns a Net::KashFlow::Receipt object

=cut

sub create_receipt {
    my ( $self, $data ) = @_;
    my $id = $self->_c( "InsertReceipt", $data );
    return $self->get_receipt($id);
}

=head2 get_invoice_payment()

Returns a Net::KashFlow::Payment object for an invoice payment.

    $kf->get_invoice_payment({
        InvoiceNumber => $id
    });

Returns a Net::KashFlow::Payment object for an invoice payment.

=cut

sub get_invoice_payment {
    my ( $self, $data ) = @_;
    my $payment;
    eval { $payment = $self->_c( "GetInvoicePayment", $data ) };
    die $@ . "\n" if $@;
    return unless $payment->{Payment};
    $payment = bless $payment->{Payment}, "Net::KashFlow::Payment";
    $payment->{kf} = $self;
    return $payment;
}

=head2 delete_invoice_payment

    $kf->delete_invoice_payment({
        InvoicePaymentNumber => 12345
    })

Deletes a specific invoice payment

Returns 1 if payment deleted

=cut

sub delete_invoice_payment {
    my ( $self, $data ) = @_;
    eval { $self->_c( "DeleteInvoicePayment", $data ) };
    die $@ . "\n" if $@;
    return 1;
}

=head2 get_vat_rates();

Returns a list of VAT rates

=cut

sub get_vat_rates {
    my $self = shift;
    my $rates;
    eval { $rates = $self->_c("GetVATRates") };
    die $@ . "\n" if $@;

    my @rates;

    if ( ref $rates->{BasicDataset} eq 'ARRAY' ) {
        for my $r ( @{ $rates->{BasicDataset} } ) {
            push @rates, $r->{Value};
        }
    }
    else {
        push @rates, $rates->{BasicDataset}->{Value};
    }
    return @rates;
}

package Net::KashFlow::Base;
use base 'Class::Accessor';

sub update {
    my $self = shift;
    my $copy = {%$self};
    delete $copy->{kf};
    $self->{kf}->_c( "Update" . $self->_this(), $copy );
}

sub delete {
    my $self = shift;
    my $copy = {%$self};
    delete $copy->{kf};
    $self->{kf}->_c( "Delete" . $self->_this(), $copy );
}

package Net::KashFlow::Customer;

=head1 Net::KashFlow::Customer

    my $c = $kf->get_customer($email);

    $c->Telephone("+44.500123456");
    $c->update;

    print $c->Address1(), $c->Address2();

Customer objects have accessors as specified by
C<http://accountingapi.com/manual_class_customer.asp> - these accessors
are not "live" in that changes to them are only sent to KashFlow on call
to the C<update> method.

This package also has a C<delete> method to remove the customer from the
database, and an C<invoices> method which returns all the
C<Net::KashFlow::Invoice> objects assigned to this customer.

=cut

use base 'Net::KashFlow::Base';
__PACKAGE__->mk_accessors(
    qw(
      CustomerID Code Name Contact Telephone Mobile Fax Email Address1 Address2
      Address3 Address4 Postcode Website EC OutsideEC Notes Source Discount
      ShowDiscount PaymentTerms ExtraText1 ExtraText2 ExtraText3 ExtraText4
      ExtraText5 ExtraText6 ExtraText7 ExtraText8 ExtraText9 ExtraText10 ExtraText11
      ExtraText12 ExtraText13 ExtraText14 ExtraText15 ExtraText16 ExtraText17
      ExtraText18 ExtraText19 ExtraText20 CheckBox1 CheckBox2 CheckBox3 CheckBox4
      CheckBox5 CheckBox6 CheckBox7 CheckBox8 CheckBox9 CheckBox10 CheckBox11
      CheckBox12 CheckBox13 CheckBox14 CheckBox15 CheckBox16 CheckBox17 CheckBox18
      CheckBox19 CheckBox20 Created Updated CurrencyID ContactTitle ContactFirstName
      ContactLastName CustHasDeliveryAddress DeliveryAddress1 DeliveryAddress2
      DeliveryAddress3 DeliveryAddress4 DeliveryPostcode
      )
);
sub _this { "Customer" }

sub invoices {
    my $self = shift;
    return map {
        $_->{kf} = $self->{kf};
        $_->{Lines} = bless $_->{Lines}, "InvoiceLineSet";    # Urgh
        bless $_, "Net::KashFlow::Invoice"
      } @{ $self->{kf}->_c( "GetInvoicesForCustomer", $self->CustomerID )
          ->{Invoice} };
}

package Net::KashFlow::Invoice;
use base 'Net::KashFlow::Base';
sub _this { "Invoice" }
__PACKAGE__->mk_accessors(
    qw/
      DueDate NetAmount ProjectID Lines CustomerReference InvoiceDate InvoiceNumber
      SuppressTotal CustomerID Customer CurrencyCode ReadableString ExchangeRate
      VATAmount AmountPaid Paid InvoiceDBID EstimateCategory NetAmount
      /
);

=head1 Net::KashFlow::Invoice

    my @i = $kf->get_customer($email)->invoices;
    for (@i) { $i->Paid(1); $i->update }

Similarly to Customer, fields found at
http://accountingapi.com/manual_class_invoice.asp

Also:

    $i->add_line({ Quantity => 1, Description => "Widgets", Rate => 100 });
    $i->pay({ PayAmount => 100 });

=cut

sub add_line {
    my ( $self, $data ) = @_;
    $self->{kf}->_c( "InsertInvoiceLine", $self->InvoiceDBID, $data );
}

sub pay {
    my ( $self, $data ) = @_;
    $data->{PayInvoice} = $self->{InvoiceNumber};
    $self->{kf}->_c( "InsertInvoicePayment", $data );
}

sub email {
    my ( $self, $data ) = @_;
    $data->{InvoiceNumber} = $self->{InvoiceNumber};
    for (qw/FromEmail FromName SubjectLine Body RecipientEmail/) {
        die "You must supply the $_ parameter" unless $data->{$_};
    }
    $self->{kf}->_c( "EmailInvoice", $data );
}

sub delete {
    my ( $self, $data ) = @_;
    $data->{InvoiceNumber} = $self->{InvoiceNumber};
    $self->{kf}->_c( "DeleteInvoice", $data );
}

package Net::KashFlow::Receipt;
use base 'Net::KashFlow::Base';
sub _this { "Receipt" }
__PACKAGE__->mk_accessors(
    qw/
      InvoiceDBID InvoiceNumber InvoiceDate DueDate Paid CustomerID
      CustomerReference NetAmount VatAmount AmountPaid Lines
      /
);

=head1 Net::KashFlow::Receipt

    my @i = $kf->get_customer($email)->receipts;
    for (@i) { $i->Paid(1); $i->update }

Just like Net::KashFlow::Invoice but for receipts. Fields at
http://accountingapi.com/manual_class_invoice.asp

Also:

    $i->add_line({ Quantity => 1, Description => "Widgets", Rate => 100 });
    $i->pay({ PayAmount => 100 });

=cut

sub add_line {
    my ( $self, $data ) = @_;
    $self->{kf}->_c( "InsertReceiptLine", $self->InvoiceDBID, $data );
}

sub delete_line {
    my ( $self, $id ) = @_;
    $self->{kf}->_c( "DeleteReceiptLine", $id, $self->{InvoiceNumber} );
}

sub pay {
    my ( $self, $data ) = @_;
    $data->{PayInvoice} = $self->{InvoiceNumber};
    $self->{kf}->_c( "InsertReceiptPayment", $data );
}

package Net::KashFlow::Payment;
use base 'Net::KashFlow::Base';
sub _this { "Payment" }
__PACKAGE__->mk_accessors(
    qw/
      PayID PayInvoice PayDate PayNote PayMethod PayAccount PayAmount
      /
);

=head1 Net::KashFlow::Payment

Payment object. Fields: http://accountingapi.com/manual_class_payment.asp

=cut

package Net::KashFlow::Supplier;
use base 'Net::KashFlow::Base';
sub _this { "Supplier" }
__PACKAGE__->mk_accessors(qw/SupplierID Code/);

=head1 AUTHOR

Simon Cozens, C<< <simon at simon-cozens.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-net-kashflow at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-KashFlow>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

I am aware that this module is WOEFULLY INCOMPLETE and I'm looking
forward to receiving patches to add new functionality to it. Currently
it does what I want and I don't have much incentive to finish it. :/

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::KashFlow


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-KashFlow>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-KashFlow>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-KashFlow>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-KashFlow/>

=back


=head1 ACKNOWLEDGEMENTS

Thanks to the UK Free Software Network (http://www.ukfsn.org/) for their
support of this module's development. For free-software-friendly hosting
and other Internet services, try UKFSN.

=head1 COPYRIGHT & LICENSE

Copyright 2009 Simon Cozens.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of Net::KashFlow
