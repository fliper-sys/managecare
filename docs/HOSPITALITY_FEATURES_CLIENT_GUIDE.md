# Hospitality and Bar Workflow Improvements

## A clearer way to manage rooms, bookings, bar orders, and payments

Manage Care now supports a more complete hospitality workflow for hotels and
bars. The improvements help staff see what has happened, record who handled
each step, and keep room availability, stock, and payments up to date.

## Hotel bookings and room history

### Booking history

Staff can open a booking history for the whole hotel or for one particular room.
The history can be narrowed down by booking status and date range. Staff can
also search by guest name, phone number, or room number.

Summary cards show the number of matching bookings, how many guests have
checked out, how many bookings were cancelled, and how much has been paid.
Each booking also shows its stay dates, status, amount paid, and remaining
balance.

### Room-specific history

From a room, staff can open a history just for that room. This makes it easier
to review previous and current stays without searching through every room's
bookings.

### Room availability after cancellation or checkout

When a booking is cancelled or a guest checks out, the room status is saved
with the booking update. The system also recalculates room availability from
the current bookings, helping prevent a room from continuing to appear booked
after its reservation has ended.

### Checkout requires payment settlement

At checkout, staff can enter the guest's payment before completing the
checkout. A booking with an outstanding balance cannot be marked as checked
out. This helps keep the room status and the guest's account consistent.

## Clear payment records

### Cash, card, and transfer

Payment screens provide separate amount fields for cash, card, and bank
transfer. The application adds the amounts together and shows the payment
total.

A guest or customer can pay with one method or combine methods. For example,
one payment can be split between cash, card, and transfer. The entered amounts
must add up to the amount due when full payment is required. Where partial
payment is allowed, the amount must be greater than zero and cannot exceed the
outstanding balance.

### Payments when booking a room

Staff can record a payment when creating a booking. The booking keeps the
amount paid and the amounts received through each payment method, so the
remaining balance can be tracked accurately.

### Extended stays

The cost of an extended stay is added to the guest's room bill as an additional
charge. It is not automatically treated as paid. The guest can settle it at
checkout, and the payment is recorded against the outstanding bill.

## Bar orders, stock handover, and payment approval

### A step-by-step bar order

Bar tabs now move through distinct stages:

1. **Order placed:** The order is saved to Tabs & Invoices.
2. **Order confirmed:** An authorised store keeper confirms the order.
3. **Drinks handed over:** The handover is confirmed when the bottles are
   actually collected. This is the point at which the bar's bottle stock is
   reduced.
4. **Payment approved:** An authorised payment worker records the cash, card,
   and/or transfer amounts and confirms the payment.

Keeping these steps separate makes it easier to tell whether an order is only
requested, confirmed, handed over, or paid.

### Who requested, handed over, and approved the order

The invoice records the worker who created the order. It separately records
the worker who confirmed the order, the worker who confirmed the drinks were
handed over, and the worker who approved payment. Names and action times are
shown in the order details when available.

This gives managers and staff a clearer activity record for each bar order.
The original order requester remains recorded if an open tab is edited later.

### Stock is counted at handover

Bottle stock is deducted when the handover is confirmed, rather than waiting
until payment. A later payment approval does not deduct the same bottles
again. Orders that have already been handed over cannot be cancelled through
the uncollected-order cancellation flow.

### Open tabs can be edited

Staff can reopen an open tab in the Bar POS, add or adjust its items, and save
the changes. The tab remains open for the confirmation, handover, and payment
steps. Editing an open tab does not convert it into a sale or mark it as paid.

### Payment receipt and sale record

Once payment has been approved, the order is recorded as a sale and the
payment method and individual tender amounts are saved. The payment
confirmation screen checks that the amounts entered add up to the order total
before accepting the payment.

## Staff roles

Bar actions are restricted by staff permissions:

- **Store keepers** can confirm bar orders and confirm bottle handover.
- **Cashiers and other workers granted the payment permission** can approve
  bar payments.
- **Owners and authorised managers** can carry out the actions allowed by
  their access level.

The store keeper's handover confirmation and the payment approver are recorded
as separate actions, even when different staff members perform them.

## What this means for day-to-day operations

- Reception staff can review booking history and room-specific stay history.
- Room status reflects current reservations more reliably after cancellations
  and checkout.
- Hotel staff can see the amount received and the outstanding balance before
  completing checkout.
- Bar teams can see who requested an order, who confirmed it, who handed over
  the drinks, and who approved payment.
- Managers can review the cash, card, and transfer amounts that make up a
  payment.
- Bottle stock is reduced once at handover, helping avoid duplicate stock
  deductions at payment time.

## Availability

The production backend and database changes for hospitality and bar payment
tracking have been applied. Staff will see the corresponding screens and
workflow changes in the Manage Care app version that includes the updated
hospitality features. Available actions depend on each worker's assigned role
and permissions.
