#!/usr/bin/env python3
"""Generate new, never-submitted synthetic documents for the bounded classifier probe.
Each arm (V0/V1/V2) gets a disjoint set with identical composition: 8 bills, 4 invoices,
4 receipts, 4 non-financial documents. Seeded, fictional names, no personal data."""
import json, random, sys

import os
rng = random.Random(int(os.environ.get("PROBE_SEED", "20260929")))
ARMS = os.environ.get("PROBE_ARMS", "V0,V1,V2").split(",")
SMALL = os.environ.get("PROBE_SMALL") == "1"
UTIL = ["Harbor Light Power", "Crestwater Utilities", "Northgate Telecom", "Valley Gas Service", "Pinecrest Water Co",
        "Summit Broadband", "Riverside Electric", "Oakline Waste Services", "Brightline Energy", "Clearview Internet",
        "Meadow Springs Water", "Ironwood Power", "Silver Lake Gas", "Hilltop Fiber", "Bayshore Electric",
        "Cedar Valley Utilities", "Lakeside Telecom", "Granite Ridge Water", "Maple Grid Energy", "Coastal Wireless",
        "Fernhill Utilities", "Stonebridge Power", "Willow Creek Water", "Redwood Networks"]
SHOPS = ["Acorn Office Supply", "Bluebird Cafe", "Copperpot Kitchen", "Delta Print Works", "Evergreen Hardware",
         "Foxglove Books", "Granary Market", "Harbor Auto Parts", "Indigo Stationers", "Juniper Garden Center",
         "Kestrel Software", "Lumen Studio", "Mariner Travel", "Nimbus Hosting", "Orchard Deli", "Parkside Pharmacy",
         "Quill Design Co", "Rowan Repair Shop", "Saffron Bistro", "Tidewater Marine", "Umber Signs", "Vantage Media",
         "Westfield Tires", "Yarrow Catering"]
BILL_ITEMS = ["Monthly service", "Metered usage", "Service connection", "Delivery charge", "Account service", "Usage charge"]
SHOP_ITEMS = ["Copy paper", "Ink cartridge", "Coffee", "Sandwich", "Software license", "Cloud storage", "Oil filter",
              "Repair labor", "Design work", "Print campaign", "Notebooks", "Setup fee"]

def money(c): return f"{c // 100}.{c % 100:02d}"
def date(): m, d = rng.randint(1, 9), rng.randint(1, 28); return f"{m}/{d}/2026"
def lines(items, n):
    rows, total = [], 0
    for name in rng.sample(items, n):
        c = rng.randint(800, 9000); total += c; rows.append(f"{name}    ${money(c)}")
    return rows, total

def bill(vendor, style):
    rows, sub = lines(BILL_ITEMS, rng.randint(3, 5)); tax = sub * 75 // 1000
    head = {"utility": "UTILITY BILL", "statement": "ACCOUNT STATEMENT", "service": "SERVICE BILL"}[style]
    return "\n".join([vendor, head, "ACCOUNT", f"Customer {rng.randint(1000, 9999)}", f"Date: {date()}",
                      f"Document {rng.randint(40000, 49999)}", "Service details", *rows,
                      f"Subtotal ${money(sub)}", f"Sales tax ${money(tax)}", f"AMOUNT DUE ${money(sub + tax)}",
                      f"Due date: {date()}"])

def invoice(vendor):
    rows, sub = lines(SHOP_ITEMS, rng.randint(3, 5)); tax = sub * 75 // 1000
    return "\n".join([vendor, "INVOICE", f"Issued: {date()}", "Billed to: Walk-in customer", f"Due date: {date()}",
                      "DESCRIPTION    LINE AMOUNT", *rows, f"Subtotal ${money(sub)}", f"Sales tax ${money(tax)}",
                      f"TOTAL DUE ${money(sub + tax)}"])

def receipt(vendor):
    rows, sub = lines(SHOP_ITEMS, rng.randint(3, 5)); tax = sub * 75 // 1000
    return "\n".join([vendor, "RECEIPT", f"Date: {date()}", *rows, f"Subtotal ${money(sub)}",
                      f"Sales tax ${money(tax)}", f"AMOUNT PAID ${money(sub + tax)}", "Thank you for your purchase"])

def negative(vendor, style):
    if style == "notice":
        events = rng.sample(["Garden planning", "Bicycle maintenance", "Seed swap", "Knitting circle", "Tool library tour",
                             "Composting basics", "Map reading", "Repair cafe", "Chess club", "Photo walk"], 2)
        return "\n".join(["COMMUNITY NOTICE", f"{rng.choice(['Skills exchange', 'Neighbourhood day', 'Library open house'])} / Saturday programme",
                          f"10:00 {events[0]}", f"11:30 {events[1]}", "Bring a notebook and reusable cup.",
                          "This is an announcement, not a purchase record."])
    rows, sub = lines(SHOP_ITEMS, 3)
    head = {"quote": "QUOTATION", "menu": "MENU", "pricelist": "PRICE LIST"}[style]
    extra = ["Valid for 30 days. This is not an invoice."] if style == "quote" else []
    return "\n".join([vendor, head, f"Date: {date()}", *rows, f"Estimated total ${money(sub)}", *extra])


def paid_invoice(vendor):
    rows, sub = lines(SHOP_ITEMS, rng.randint(3, 5)); tax = sub * 75 // 1000
    return "\n".join([vendor, "TAX INVOICE", f"Invoice date: {date()}", *rows, f"Subtotal ${money(sub)}",
                      f"Tax ${money(tax)}", f"TOTAL ${money(sub + tax)}", f"PAID {date()}", "Balance due $0.00"])

def payment_confirmation(vendor):
    return "\n".join([f"{vendor} payment confirmation", f"Thank you. We received your payment on {date()}.",
                      f"Amount paid: ${money(rng.randint(1500, 30000))}", f"Confirmation number {rng.randint(100000, 999999)}",
                      "Payment method: card ending 4242"])

def estimate(vendor):
    rows, sub = lines(SHOP_ITEMS, 3)
    return "\n".join([vendor, "ESTIMATE", f"Prepared {date()}", *rows, f"Estimated total ${money(sub)}",
                      "Prices are estimates. No payment is due."])

util, shops = UTIL[:], SHOPS[:]
rng.shuffle(util); rng.shuffle(shops)
out = []
for arm in ARMS:
    for i, style in enumerate(["utility", "utility", "utility", "utility", "statement", "statement", "service", "service"]):
        out.append(dict(id=f"{arm}-bill-{i+1}", arm=arm, label="bill", text=bill(util.pop(), style)))
    for i in range(2 if SMALL else 4): out.append(dict(id=f"{arm}-invoice-{i+1}", arm=arm, label="invoice", text=invoice(shops.pop())))
    for i in range(2 if SMALL else 4): out.append(dict(id=f"{arm}-receipt-{i+1}", arm=arm, label="receipt", text=receipt(shops.pop())))
    for i, style in enumerate([] if SMALL else ["notice", "quote", "menu", "pricelist"]):
        out.append(dict(id=f"{arm}-negative-{i+1}", arm=arm, label="not_receipt", text=negative(rng.choice(SHOPS), style)))

if os.environ.get("PROBE_VALIDATION") == "1":
    out = []
    styles = ["utility", "statement", "service"]
    pool_u = [f"{a} {b}" for a in ["North", "South", "East", "West", "Upper", "Lower", "Old", "New"] for b in ["Ridge Power", "Bay Water", "Vale Gas", "Point Telecom"]]
    pool_s = [f"{a} {b}" for a in ["Amber", "Birch", "Cobalt", "Dune", "Elm", "Flint", "Grove", "Heron"] for b in ["Supply", "Kitchen", "Studio", "Works"]]
    rng.shuffle(pool_u); rng.shuffle(pool_s)
    for i in range(16): out.append(dict(id=f"VAL-bill-{i+1}", arm="V5", label="bill", text=bill(pool_u.pop(), styles[i % 3])))
    for i in range(4): out.append(dict(id=f"VAL-invoice-{i+1}", arm="V5", label="invoice", text=invoice(pool_s.pop())))
    for i in range(4): out.append(dict(id=f"VAL-paidinvoice-{i+1}", arm="V5", label="invoice", text=paid_invoice(pool_s.pop())))
    for i in range(4): out.append(dict(id=f"VAL-receipt-{i+1}", arm="V5", label="receipt", text=receipt(pool_s.pop())))
    for i in range(4): out.append(dict(id=f"VAL-payment-{i+1}", arm="V5", label="receipt", text=payment_confirmation(pool_s.pop())))
    for i, style in enumerate(["notice", "quote", "menu", "pricelist"]):
        out.append(dict(id=f"VAL-negative-{i+1}", arm="V5", label="not_receipt", text=negative(pool_s.pop(), style)))
    for i in range(4): out.append(dict(id=f"VAL-estimate-{i+1}", arm="V5", label="not_receipt", text=estimate(pool_s.pop())))

if os.environ.get("PROBE_PAID") == "1":
    out = []
    pool = [f"{a} {b}" for a in ["Ash", "Bay", "Cove", "Dell", "Fern", "Glen", "Holt", "Isle", "Knoll"] for b in ["Traders", "Outfitters", "Labs"]]
    rng.shuffle(pool)
    for arm in ["V0", "V3", "V4"]:
        for i in range(6): out.append(dict(id=f"PAID-{arm}-{i+1}", arm=arm, label="invoice", text=paid_invoice(pool.pop())))
with open(sys.argv[1], "w") as f:
    for row in out: f.write(json.dumps(row) + "\n")
print(len(out), "inputs")
