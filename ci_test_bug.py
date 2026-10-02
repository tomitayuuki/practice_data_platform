def calculate_total_with_tax(price, tax_rate):
    """価格に税率を適用した合計金額を返す（はずだが、バグがある）"""
    return price - price * tax_rate
